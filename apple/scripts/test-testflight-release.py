#!/usr/bin/env python3
"""Offline release-contract tests. They use no Apple account, key, build or network."""
import contextlib
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import plistlib
import stat
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import testflight_release as release


class FakeApple:
    def __init__(self, *, processing="VALID", upload="COMPLETE", audience="INTERNAL_ONLY",
                 group_has_build=True, tester="tester", group="group", bundle=release.BUNDLE,
                 expired=False, upload_errors=None):
        self.calls = []
        self.app = {"type": "apps", "id": "app", "attributes": {"bundleId": bundle}}
        self.version = {"type": "preReleaseVersions", "id": "version", "attributes": {"version": "0.1.0"}}
        self.build = {"type": "builds", "id": "build", "attributes": {
            "version": "28", "processingState": processing, "buildAudienceType": audience, "expired": expired},
            "relationships": {"preReleaseVersion": {"data": {"id": "version"}}}}
        self.upload = {"type": "buildUploads", "id": "upload", "attributes": {
            "cfBundleVersion": "28", "cfBundleShortVersionString": "0.1.0",
            "state": {"state": upload, "errors": upload_errors or []}}}
        self.group, self.tester, self.group_has_build = group, tester, group_has_build

    def request(self, path, params=None):
        self.calls.append((path, params))
        if path == "/v1/apps":
            return {"data": [self.app]}
        if path == "/v1/apps/app/buildUploads":
            return {"data": [self.upload]}
        if path == "/v1/builds":
            return {"data": [self.build], "included": [self.version]}
        if path == "/v1/builds/build":
            return {"data": self.build, "included": [self.app, self.version, {
                "type": "buildBetaDetails", "id": "details", "attributes": {"internalBuildState": "IN_BETA_TESTING"}}]}
        if path == "/v1/apps/app/betaGroups":
            return {"data": [{"id": self.group, "attributes": {"isInternalGroup": True, "hasAccessToAllBuilds": True}}]}
        if path == "/v1/betaGroups/group/builds":
            return {"data": [self.build] if self.group_has_build else []}
        if path == "/v1/betaGroups/group/betaTesters":
            return {"data": [{"id": self.tester}]}
        raise AssertionError("Unexpected test request: " + path)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        release.save(self.folder, "manifest.json", {"bundleIdentifier": release.BUNDLE,
                     "appStoreConnectAppID": "app", "version": "0.1.0", "build": "28"})
        release.save(self.folder, "groups-before.json", [{"id": "group"}])
        release.save(self.folder, "testers-before.json", {"group": [{"id": "tester"}]})

    def test_accepted_processing_failed_and_unknown_version_numbers_remain_reserved(self):
        uploads = [{"attributes": {"cfBundleVersion": number, "cfBundleShortVersionString": version,
                    "state": {"state": state}}} for number, version, state in [
            ("27", "0.1.0", "PROCESSING"), ("29", "0.1.0", "FAILED"), ("99", "2.0.0", "COMPLETE")]]
        builds = [{"attributes": {"version": "30.4"}}]
        reserved = release.reserved_numbers("0.1.0", uploads, builds, {})
        self.assertEqual(reserved, {"27", "29", "30.4"})
        self.assertEqual(release.next_number(reserved), "31")

    def test_own_app_discovery_checks_bundle_and_ambiguity(self):
        with self.assertRaises(release.ReleaseError):
            release.find_app(FakeApple(bundle="other.bundle"))
        class Ambiguous:
            def request(self, path, params=None):
                return {"data": [FakeApple().app, FakeApple().app]}
        with self.assertRaises(release.ReleaseError):
            release.find_app(Ambiguous())

    def test_success_requires_processed_internal_build_existing_group_and_membership(self):
        with patch.object(release, "credentials", side_effect=AssertionError("No real credentials in offline tests")):
            result = release.collect_status(FakeApple(), self.folder)
        self.assertTrue(result["availableToExistingInternalTesters"])
        self.assertTrue(result["testersUnchanged"])
        self.assertTrue(result["internalGroupSetUnchanged"])

    def test_processing_or_missing_group_assignment_is_pending(self):
        for api in (FakeApple(processing="PROCESSING"), FakeApple(group_has_build=False), FakeApple(upload="PROCESSING")):
            with self.subTest(api=api):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(release.status(api, self.folder), 2)
                self.assertFalse(release.read(self.folder, "availability.json")["availableToExistingInternalTesters"])

    def test_identity_audience_expiry_and_membership_changes_cannot_pass(self):
        for values in ({"audience": "APP_STORE_ELIGIBLE"}, {"expired": True}, {"tester": "replacement"},
                       {"group": "replacement"}, {"bundle": "other.bundle"}, {"processing": "INVALID"},
                       {"upload_errors": [{"code": "FAILED"}]}):
            with self.subTest(values=values):
                with self.assertRaises(release.ReleaseError):
                    release.collect_status(FakeApple(**values), self.folder)

    def test_discovery_never_replaces_an_existing_tester_baseline(self):
        original = release.read(self.folder, "testers-before.json")
        with self.assertRaisesRegex(release.ReleaseError, "changed since"):
            release.baseline(FakeApple(tester="different"), FakeApple().app, self.folder)
        self.assertEqual(release.read(self.folder, "testers-before.json"), original)

    def test_a_reserved_number_cannot_reach_archive_or_upload(self):
        api = FakeApple(upload="PROCESSING")
        with self.assertRaisesRegex(release.ReleaseError, "accepted/reserved"):
            release.unused(api, api.app, "0.1.0", "28", self.folder, "preflight.json")
        self.assertFalse((self.folder / "preflight.json").exists())

    def test_status_ready_has_zero_exit_and_wait_times_out_pending(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(release.status(FakeApple(), self.folder), 0)
        with patch.object(release, "collect_status", return_value={"availableToExistingInternalTesters": False}), \
                patch.object(release.time, "monotonic", side_effect=[0, 1, 3]), \
                patch.object(release.time, "sleep") as sleep, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(release.status(None, self.folder, timeout=2, interval=15), 2)
            sleep.assert_called_once_with(1)

    def test_hidden_untracked_source_is_rejected_even_when_git_config_hides_it(self):
        repository = self.folder / "source-repository"
        repository.mkdir()
        hooks = self.folder / "no-hooks"
        hooks.mkdir()
        def git(*arguments):
            return subprocess.run(["git", "-C", str(repository), *arguments], check=True,
                                  capture_output=True, text=True).stdout.strip()
        git("init", "-q", "-b", "main")
        git("config", "user.name", "Release contract fixture")
        git("config", "user.email", "release-tests@example.invalid")
        git("config", "core.hooksPath", str(hooks))
        git("config", "commit.gpgSign", "false")
        git("config", "status.showUntrackedFiles", "no")
        (repository / "README.md").write_text("Tracked fixture.\n")
        (repository / ".gitignore").write_text(".local/\n")
        git("add", "README.md", ".gitignore")
        git("commit", "-q", "-m", "Create release source fixture")
        with patch.object(release, "ROOT", repository):
            expected = release.source()
            ignored = repository / ".local"
            ignored.mkdir()
            (ignored / "proof.json").write_text("{}")
            self.assertEqual(release.source(), expected, "Private ignored release evidence remains allowed")
            untracked = repository / "apple/sources/Untracked.swift"
            untracked.parent.mkdir(parents=True)
            untracked.write_text("struct Untracked {}\n")
            self.assertEqual(git("status", "--porcelain"), "", "Fixture reproduces the hidden-file configuration")
            with self.assertRaisesRegex(release.ReleaseError, "clean source checkout"):
                release.source()
            with self.assertRaisesRegex(release.ReleaseError, "clean source checkout"):
                release.frozen(expected)

    def test_receipt_binds_exact_source_and_unchanged_check_log(self):
        expected = {"sourceCommit": "commit", "sourceTree": "tree"}
        log = self.folder / "check.log"
        log.write_text("passed")
        release.save(self.folder, "checks.json", {**expected, "passed": True,
                     "logSHA256": hashlib.sha256(log.read_bytes()).hexdigest()})
        release.verify_receipt(self.folder, expected)
        with self.assertRaises(release.ReleaseError):
            release.verify_receipt(self.folder, {**expected, "sourceTree": "another"})
        log.write_text("changed")
        with self.assertRaises(release.ReleaseError):
            release.verify_receipt(self.folder, expected)

    def source_repository(self):
        repository = self.folder / "preview-source"
        repository.mkdir()
        hooks = self.folder / "preview-no-hooks"
        hooks.mkdir()
        def git(*arguments):
            return subprocess.run(["git", "-C", str(repository), *arguments], check=True,
                                  capture_output=True, text=True).stdout.strip()
        git("init", "-q", "-b", "main")
        git("config", "user.name", "Release contract fixture")
        git("config", "user.email", "release-tests@example.invalid")
        git("config", "core.hooksPath", str(hooks))
        git("config", "commit.gpgSign", "false")
        (repository / "README.md").write_text("Reviewed source.\n")
        git("add", "README.md")
        git("commit", "-q", "-m", "Create reviewed fixture")
        return repository, git

    def test_preview_requires_clean_exact_branch_and_keeps_default_main_identity(self):
        repository, git = self.source_repository()
        with patch.object(release, "ROOT", repository):
            main = release.source()
            self.assertEqual(set(main), {"sourceCommit", "sourceTree"})
            release.frozen(main)
            with self.assertRaises(release.ReleaseError):
                release.source("main")
            git("checkout", "-q", "-b", "codex/preview")
            with self.assertRaisesRegex(release.ReleaseError, "integrated main"):
                release.source()
            preview = release.source("codex/preview")
            self.assertEqual(preview, {**main, "previewBranch": "codex/preview"})
            release.frozen(preview)
            git("checkout", "-q", "-b", "codex/other")
            self.assertEqual(git("rev-parse", "HEAD"), preview["sourceCommit"])
            with self.assertRaisesRegex(release.ReleaseError, "original named branch"):
                release.frozen(preview)
            git("checkout", "-q", "codex/preview")
            for path in (repository / "README.md", repository / "untracked.swift"):
                original = path.read_text() if path.exists() else None
                path.write_text("Unreviewed source.\n")
                with self.assertRaisesRegex(release.ReleaseError, "clean source checkout"):
                    release.frozen(preview)
                if original is None:
                    path.unlink()
                else:
                    path.write_text(original)
            git("commit", "-q", "--allow-empty", "-m", "Different commit, same tree")
            self.assertEqual(git("rev-parse", "HEAD^{tree}"), preview["sourceTree"])
            with self.assertRaisesRegex(release.ReleaseError, "Source changed"):
                release.frozen(preview)
            git("checkout", "-q", "--detach", preview["sourceCommit"])
            with self.assertRaisesRegex(release.ReleaseError, "original named branch"):
                release.frozen(preview)
            with self.assertRaisesRegex(release.ReleaseError, "named non-main"):
                release.archive(None, self.folder, preview["sourceCommit"], True)

    def test_preview_context_and_flag_types_are_not_coerced(self):
        for value in (None, True, False, 0, 1, [], {}, "", "main", "HEAD", "-branch", "bad..branch"):
            with self.subTest(value=value):
                with self.assertRaises(release.ReleaseError):
                    release.frozen({"sourceCommit": "a", "sourceTree": "b", "previewBranch": value})
        for value in (None, 0, 1, "true", [], {}):
            with self.subTest(flag=value):
                with self.assertRaisesRegex(release.ReleaseError, "boolean"):
                    release.archive(None, self.folder, "abcdef1", value)
        for command in ("discover", "upload", "status", "wait"):
            with self.subTest(command=command), \
                    patch.object(release, "delivery_directory") as directory, \
                    patch.object(release, "AppleAPI") as api, \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(release.main([command, "--output", str(self.folder),
                                               "--reviewed-preview"]), 1)
                directory.assert_not_called()
                api.assert_not_called()

    def test_preview_archive_freezes_branch_in_manifest_and_check_receipt(self):
        repository, git = self.source_repository()
        git("checkout", "-q", "-b", "codex/preview")
        git("checkout", "-q", "-b", "codex/different-review")
        (repository / "README.md").write_text("Different reviewed tree.\n")
        git("add", "README.md")
        git("commit", "-q", "-m", "Different review fixture")
        other_review = git("rev-parse", "HEAD")
        git("checkout", "-q", "codex/preview")
        (self.folder / "manifest.json").unlink()
        release.save(self.folder, "discovery.json", {"bundleIdentifier": release.BUNDLE, "version": "0.1.0"})
        release.save(self.folder, "app.json", FakeApple().app)
        def fake_logged(arguments, path):
            release.frozen(release.source("codex/preview"))
            path.write_text("Checks passed." if path.name == "check.log" else "Archive fixture.")
        with patch.object(release, "ROOT", repository), \
                patch.object(release, "identity", return_value=("0.1.0", "28")), \
                patch.object(release, "team", return_value="TESTTEAM01"), \
                patch.object(release, "authentication", return_value=[]), \
                patch.object(release, "unused"), patch.object(release, "verify_archive"), \
                patch.object(release, "logged", side_effect=fake_logged), \
                contextlib.redirect_stdout(io.StringIO()):
            expected = release.source("codex/preview")
            with self.assertRaisesRegex(release.ReleaseError, "reviewed source tree"):
                release.archive(FakeApple(), self.folder, other_review, True)
            release.archive(FakeApple(), self.folder, expected["sourceCommit"], True)
            manifest = release.read(self.folder, "manifest.json")
            self.assertEqual(manifest["previewBranch"], "codex/preview")
            self.assertEqual(release.read(self.folder, "checks.json")["previewBranch"], "codex/preview")
            release.verify_receipt(self.folder, manifest)
            for branch in (None, "codex/other"):
                changed = dict(manifest)
                if branch is None:
                    changed.pop("previewBranch")
                else:
                    changed["previewBranch"] = branch
                with self.assertRaises(release.ReleaseError):
                    release.verify_receipt(self.folder, changed)
            git("checkout", "-q", "-b", "codex/other")
            api = FakeApple()
            with self.assertRaisesRegex(release.ReleaseError, "original named branch"):
                release.upload(api, self.folder)
            self.assertEqual(api.calls, [])
            self.assertNotIn("uploadStartedAt", release.read(self.folder, "manifest.json"))

    def test_upload_attempt_is_not_automatically_replayed(self):
        manifest = release.read(self.folder, "manifest.json")
        manifest["uploadStartedAt"] = "attempted"
        release.save(self.folder, "manifest.json", manifest)
        api = FakeApple()
        with self.assertRaisesRegex(release.ReleaseError, "inspect status"):
            release.upload(api, self.folder)
        self.assertEqual(api.calls, [])

    def test_a_waiting_upload_reloads_the_attempt_under_its_lock(self):
        stale = release.read(self.folder, "manifest.json")
        @contextlib.contextmanager
        def another_caller_finished(folder, name):
            release.save(folder, "manifest.json", {**stale, "uploadStartedAt": "already attempted"})
            yield
        api = FakeApple()
        with patch.object(release, "exclusive", another_caller_finished):
            with self.assertRaisesRegex(release.ReleaseError, "upload was attempted"):
                release.upload(api, self.folder)
        self.assertEqual(release.read(self.folder, "manifest.json")["uploadStartedAt"], "already attempted")
        self.assertEqual(api.calls, [])

    def test_operation_lock_rejects_parallel_commands_and_cleans_up_on_error(self):
        for name in ("archive-in-progress", "upload-in-progress"):
            with self.subTest(name=name):
                with release.exclusive(self.folder, name):
                    with self.assertRaises(release.ReleaseError):
                        with release.exclusive(self.folder, name):
                            self.fail("Concurrent operation acquired an owned lock")
                self.assertFalse((self.folder / name).exists())
                with self.assertRaises(RuntimeError):
                    with release.exclusive(self.folder, name):
                        raise RuntimeError("fixture failure")
                self.assertFalse((self.folder / name).exists())

    def test_private_output_rejects_source_symlinks_and_unowned_files(self):
        root = (self.folder / "repository").resolve()
        (root / ".local").mkdir(parents=True)
        (root / "apple").mkdir()
        existing = root / ".local" / "valuable"
        existing.mkdir()
        (existing / "report").write_text("preserve")
        escaped = root / ".local" / "escaped"
        escaped.symlink_to(root / "apple", target_is_directory=True)
        with patch.object(release, "ROOT", root):
            for destination in (root / "apple" / "output", escaped / "output", existing):
                with self.subTest(destination=destination):
                    with self.assertRaises(release.ReleaseError):
                        release.delivery_directory(destination, "discover")
            fresh = root / ".local" / "delivery"
            self.assertEqual(release.delivery_directory(fresh, "discover"), fresh)
            self.assertEqual(release.delivery_directory(fresh, "status"), fresh)
        self.assertEqual((existing / "report").read_text(), "preserve")
        self.assertFalse((root / "apple" / "output").exists())

    def test_concurrent_report_writers_leave_a_complete_atomic_receipt(self):
        variants = [{"available": index, "payload": "record" * 100} for index in range(32)]
        def write(value):
            release.save(self.folder, "availability.json", value)
            return release.read(self.folder, "availability.json") in variants
        with ThreadPoolExecutor(max_workers=8) as executor:
            self.assertTrue(all(executor.map(write, variants)))
        self.assertIn(release.read(self.folder, "availability.json"), variants)
        self.assertEqual(list(self.folder.glob("*.tmp")), [])

    def test_private_reports_never_follow_a_symlink(self):
        original = self.folder / "original"
        original.write_text("preserve")
        (self.folder / "report.json").symlink_to(original)
        with self.assertRaises(release.ReleaseError):
            release.save(self.folder, "report.json", {"changed": True})
        self.assertEqual(original.read_text(), "preserve")

    def test_status_error_preserves_last_success_proof(self):
        result = {"availableToExistingInternalTesters": True, "checkedAt": "previous proof"}
        release.save(self.folder, "availability.json", result)
        with patch.object(release, "delivery_directory", return_value=self.folder), \
                patch.object(release, "collect_status", side_effect=release.ReleaseError("Apple API unavailable")), \
                patch.object(release.os, "umask"), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(release.main(["status", "--output", str(self.folder)]), 1)
        self.assertEqual(release.read(self.folder, "availability.json"), result)
        self.assertFalse(release.read(self.folder, "status-error.json")["availableToExistingInternalTesters"])

    def test_missing_or_mismatched_config_is_rejected_without_key_contents(self):
        key = self.folder / "AuthKey_TESTKEY.p8"
        key.write_text("test placeholder; never a real credential")
        values = {"LAUDER_ASC_KEY_PATH": str(key), "LAUDER_ASC_ISSUER_ID": "00000000-0000-0000-0000-000000000000"}
        with patch.dict(release.os.environ, values, clear=True):
            with patch.object(Path, "read_bytes", side_effect=AssertionError("No key contents required for configuration")):
                selected, key_id, _ = release.credentials()
                self.assertEqual(selected, key)
                self.assertEqual(key_id, "TESTKEY")
            with patch.dict(release.os.environ, {"LAUDER_ASC_KEY_ID": "WRONGKEY"}):
                with self.assertRaises(release.ReleaseError):
                    release.credentials()
        with patch.dict(release.os.environ, {}, clear=True):
            with self.assertRaises(release.ReleaseError):
                release.credentials()

    def test_archive_cannot_use_a_different_review_tree(self):
        with patch.object(release, "source", return_value={"sourceCommit": "main", "sourceTree": "main-tree"}), \
                patch.object(release, "git", side_effect=["reviewed-commit", "other-tree"]):
            with self.assertRaisesRegex(release.ReleaseError, "reviewed source tree"):
                release.archive(None, self.folder, "abcdef1")
        self.assertFalse((self.folder / "archive-in-progress").exists())

    def test_archive_options_symlink_preserves_unrelated_file_and_never_invokes_xcode(self):
        # Exercise the archive path, with only its account/build/check prerequisites mocked.
        (self.folder / "manifest.json").unlink()
        release.save(self.folder, "discovery.json", {"bundleIdentifier": release.BUNDLE, "version": "0.1.0"})
        release.save(self.folder, "app.json", FakeApple().app)
        unrelated = self.folder / "unrelated"
        unrelated.write_bytes(b"preserve unrelated content")
        unrelated.chmod(0o640)
        (self.folder / "ExportOptions.plist").symlink_to(unrelated)
        initial = {"sourceCommit": "a" * 40, "sourceTree": "reviewed-tree"}
        def fake_checks(arguments, path):
            self.assertEqual(arguments, [str(release.ROOT / "scripts/check")])
            path.write_text("Checks passed.")
        with patch.object(release, "source", return_value=initial), \
                patch.object(release, "git", side_effect=["b" * 40, "reviewed-tree"]), \
                patch.object(release, "identity", return_value=("0.1.0", "28")), \
                patch.object(release, "team", return_value="TESTTEAM01"), \
                patch.object(release, "authentication", return_value=[]), \
                patch.object(release, "unused"), patch.object(release, "frozen"), \
                patch.object(release, "logged", side_effect=fake_checks) as logged, \
                patch.object(release.subprocess, "run") as command:
            with self.assertRaisesRegex(release.ReleaseError, "symbolic link"):
                release.archive(FakeApple(), self.folder, "b" * 40)
        logged.assert_called_once()
        command.assert_not_called()
        self.assertEqual(unrelated.read_bytes(), b"preserve unrelated content")
        self.assertEqual(stat.S_IMODE(unrelated.stat().st_mode), 0o640)
        self.assertTrue((self.folder / "ExportOptions.plist").is_symlink())
        self.assertFalse((self.folder / "archive-in-progress").exists())

    def test_binary_private_output_retains_restricted_descriptor_permissions(self):
        output = self.folder / "ExportOptions.plist"
        output.write_bytes(b"old")
        output.chmod(0o644)
        content = plistlib.dumps(release.export_options("TESTTEAM01"))
        with release.private_file(output, mode="wb") as stream:
            stream.write(content)
        self.assertEqual(output.read_bytes(), content)
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)

    def test_internal_export_policy_keeps_version_and_audience_fixed(self):
        options = release.export_options("LOCAL_TEAM")
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["destination"], "upload")
        self.assertIs(options["testFlightInternalTestingOnly"], True)
        self.assertIs(options["manageAppVersionAndBuildNumber"], False)

    def test_archive_digest_detects_resource_and_symbol_changes(self):
        app = self.folder / "Lauder.app"
        app.mkdir()
        (app / "resource").write_bytes(b"resource")
        symbols = self.folder / "Lauder.dSYM"
        symbols.write_bytes(b"symbols")
        initial = release.archive_digest(app, symbols, {})
        (app / "resource").write_bytes(b"changed resource")
        self.assertNotEqual(initial, release.archive_digest(app, symbols, {}))
        (app / "resource").write_bytes(b"resource")
        symbols.write_bytes(b"changed symbols")
        self.assertNotEqual(initial, release.archive_digest(app, symbols, {}))

    def test_archive_routing_metadata_is_checked_and_immutable_fields_are_hashed(self):
        archive = self.folder / "Lauder-build28.xcarchive"
        app = archive / "Products/Applications/Lauder.app"
        app.mkdir(parents=True)
        (app / "binary").write_bytes(b"binary")
        symbols = self.folder / "symbols"
        symbols.write_bytes(b"symbols")
        manifest = {"version": "0.1.0", "build": "28"}
        metadata = {"ArchiveVersion": 2, "Name": "Lauder", "SchemeName": "Lauder", "ApplicationProperties": {
            "ApplicationPath": "Applications/Lauder.app", "CFBundleIdentifier": release.BUNDLE,
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "28", "Team": "TESTTEAM01",
            "SigningIdentity": "Test fixture"}}
        path = archive / "Info.plist"
        path.write_bytes(plistlib.dumps(metadata))
        initial = release.archive_metadata(archive, manifest, "TESTTEAM01")
        fingerprint = release.archive_digest(app, symbols, initial)
        metadata["Distributions"] = [{"Test fixture": "new upload history"}]
        path.write_bytes(plistlib.dumps(metadata))
        unchanged = release.archive_metadata(archive, manifest, "TESTTEAM01")
        self.assertEqual(fingerprint, release.archive_digest(app, symbols, unchanged))
        metadata["ApplicationProperties"]["SigningIdentity"] = "Changed fixture"
        path.write_bytes(plistlib.dumps(metadata))
        changed = release.archive_metadata(archive, manifest, "TESTTEAM01")
        self.assertNotEqual(fingerprint, release.archive_digest(app, symbols, changed))
        metadata["ApplicationProperties"]["ApplicationPath"] = "Applications/Other.app"
        path.write_bytes(plistlib.dumps(metadata))
        with self.assertRaises(release.ReleaseError):
            release.archive_metadata(archive, manifest, "TESTTEAM01")
        metadata["ApplicationProperties"]["ApplicationPath"] = "Applications/Lauder.app"
        path.write_bytes(plistlib.dumps(metadata))
        (archive / "Products/Applications/Other.app").mkdir()
        with self.assertRaises(release.ReleaseError):
            release.archive_metadata(archive, manifest, "TESTTEAM01")

    def test_membership_drift_blocks_upload_before_export_or_attempt_receipt(self):
        (self.folder / "ExportOptions.plist").write_bytes(plistlib.dumps(release.export_options("TESTTEAM01")))
        with patch.object(release, "frozen"), patch.object(release, "verify_receipt"), \
                patch.object(release, "verify_archive"), patch.object(release, "team", return_value="TESTTEAM01"), \
                patch.object(release, "authentication", return_value=[]), patch.object(release, "unused"), \
                patch.object(release.subprocess, "run") as command:
            with self.assertRaisesRegex(release.ReleaseError, "changed since"):
                release.upload(FakeApple(tester="replacement"), self.folder)
        command.assert_not_called()
        self.assertNotIn("uploadStartedAt", release.read(self.folder, "manifest.json"))
        self.assertFalse((self.folder / "upload-in-progress").exists())

    def test_api_refuses_foreign_host_before_loading_credentials(self):
        api = release.AppleAPI()
        with patch.object(api, "token", side_effect=AssertionError("Must not load secrets")):
            with self.assertRaises(release.ReleaseError):
                api.request("https://example.invalid/v1/apps")

    def test_pagination_cannot_loop(self):
        class Loop:
            def request(self, path, params=None):
                return {"data": [], "links": {"next": "/repeat"}}
        with self.assertRaises(release.ReleaseError):
            release.resources(Loop(), "/repeat")

    def test_help_runs_without_credentials_or_crypto_dependency(self):
        process = subprocess.run([sys.executable, "-I", "-B", "apple/scripts/testflight", "--help"],
                                 cwd=release.ROOT, capture_output=True, text=True, env={})
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn("discover", process.stdout)


if __name__ == "__main__":
    unittest.main()
