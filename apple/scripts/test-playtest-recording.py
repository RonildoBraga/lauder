#!/usr/bin/env python3
"""Offline recording lifecycle regressions using owned child pipes, without Simulator."""

import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("playtest", str(Path(__file__).with_name("playtest")))
playtest = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(playtest)
POPEN = subprocess.Popen


class RecordingTests(unittest.TestCase):
    def setUp(self):
        self.children = []

    def tearDown(self):
        for child in self.children:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=5)
            child.stdout.close()

    def start(self, script, timeout=0.1):
        def launch(_command, **options):
            child = POPEN([sys.executable, "-u", "-c", script], **options)
            self.children.append(child)
            return child

        with patch.object(playtest.subprocess, "Popen", side_effect=launch):
            return playtest.start_recording("offline", "unused.mp4", timeout=timeout)

    def assert_start_fails(self, script):
        started = time.monotonic()
        with self.assertRaisesRegex(SystemExit, "Screen recording did not start"):
            self.start(script)
        self.assertLess(time.monotonic() - started, 2)
        self.assertIsNotNone(self.children[0].returncode, "startup failure must reap its child")
        self.assertTrue(self.children[0].stdout.closed)

    def test_silent_output_times_out_and_reaps_the_child(self):
        self.assert_start_fails("import time; time.sleep(5)")
        self.assertLess(self.children[0].returncode, 0, "do not wait for the child's natural exit")

    def test_partial_start_message_without_newline_times_out(self):
        self.assert_start_fails(
            "import sys, time; sys.stdout.write('Recording starte'); sys.stdout.flush(); time.sleep(5)")

    def test_split_start_message_without_newline_succeeds(self):
        child = self.start(
            "import sys, time; sys.stdout.write('Recording '); sys.stdout.flush(); "
            "time.sleep(0.02); sys.stdout.write('started'); sys.stdout.flush(); time.sleep(5)",
            timeout=3)
        self.assertIs(child, self.children[0])
        self.assertIsNone(child.returncode)
        playtest.stop_recording(child, timeout=1)
        self.assertIsNotNone(child.returncode)
        self.assertTrue(child.stdout.closed)

    def test_early_exit_with_unterminated_diagnostic_fails_and_is_reaped(self):
        self.assert_start_fails(
            "import sys; sys.stdout.write('Recording unavailable'); sys.stdout.flush(); sys.exit(9)")

    def test_stdout_eof_while_process_lives_fails_without_waiting_for_deadline(self):
        self.assert_start_fails("import os, time; os.close(1); os.close(2); time.sleep(5)")

    def test_shutdown_kills_and_reaps_a_child_that_ignores_interrupt(self):
        child = self.start(
            "import signal, sys, time; signal.signal(signal.SIGINT, signal.SIG_IGN); "
            "sys.stdout.write('Recording started\\n'); sys.stdout.flush(); time.sleep(5)",
            timeout=3)
        started = time.monotonic()
        playtest.stop_recording(child, timeout=0.05)
        self.assertLess(time.monotonic() - started, 2)
        self.assertIsNotNone(child.returncode, "kill must be followed by a bounded wait")
        self.assertLess(child.returncode, 0)
        self.assertTrue(child.stdout.closed)


if __name__ == "__main__":
    unittest.main()
