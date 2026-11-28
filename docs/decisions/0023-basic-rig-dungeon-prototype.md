# ADR 0023 — basic body rig and connected dungeon prototype

**Date:** 29 November 2026. **Status:** assigned implementation; fresh validation pending.

## Context and authority

After testing the duel, the maintainer said it did not feel Soulslike and lacked Eitr's dungeon/corridor journey. They selected the earlier Blender skeleton while setting the external character mesh aside, then clarified: **“We don’t need the detailed hand, we just need a basic limb skeleton armature for the animation.”** They subsequently assigned **“Proceed”** to the combined animated-mannequin/dungeon recommendation (project chat; no public permalink). [Issue #243](https://github.com/RonildoBraga/lauder/issues/243) owns progress; [#241](https://github.com/RonildoBraga/lauder/issues/241) retains the feedback and source audit.

## Decision

Keep Swift/RealityKit, the shared input/lifecycle/collision path and one authoritative combat clock. Reuse the original 17-bone body armature and useful locomotion, with plain rigid limb shapes, simple hands and separate sword/shield props. Blender owns the source poses; a small generated pose resource drives the matching hierarchy in RealityKit. This avoids external character skin, texture and detailed finger work. Melee poses follow the accepted action's clock; they do not schedule damage or move the collision body independently.

Replace the active arena with one flat connected route: safe checkpoint, bent approach, first sentry room, western junction/recovery alcove, second room, far-side return shortcut and exit. One layout value supplies floors, walls, starts and triggers to rules and presentation. One active encounter at a time is sufficient. The dungeon owner delegates to the existing duel simulation instead of duplicating hero state or time.

Clearing a room permits continued exploration. Health/stamina carry into the next encounter. A nearby recovery find restores up to 40 health, once per life and outside combat; at full health it remains available. The shortcut opens from its far side. Death Retry restores encounters and the find while retaining an opened shortcut; Pause Restart begins the whole route again. The shortcut is a return/navigation loop; sequential encounter activation means it does not skip the first required fight after death. Reaching the exit after both encounters completes the run. These are this prototype's rules, not claims about Eitr's final design.

Keep the selected 35° pitch/45° yaw orthographic framing. Camera-near walls use deliberate cutaways while retaining solid collision. Focus requires an engaged, visible opponent; an idle guard may appear through a clear doorway before engagement. Ambiguous ground warning envelopes are omitted near blocking scenery; committed weapon/body poses remain the primary cue.

## Relationship to ADR 0002

This first route is a manually maintained `DungeonLayout.swift` literal shared by rules and presentation. That is a narrow greybox departure from [ADR 0002](0002-blender-source-of-truth.md), whose Blender authoring/export pipeline remains preserved for the historical bridge. It avoids adding a level-import contract while testing one disposable route. Before a second route or environment art, whichever comes first, revisit moving this layout into the existing Blender exporter. That follow-up is a design recommendation recorded on [#254](https://github.com/RonildoBraga/lauder/issues/254), not a claim that a new production pipeline has been approved.

## Boundaries and validation

The mannequin has no settled story identity. No imported character mesh, detailed hands, procedural levels, navmesh, inventory, progression tree, extra combat actions or engine migration is assigned. Historical rig/mesh/bridge sources remain preserved.

Validate the first animated corridor/room encounter, then the connected route. Native checks cover collision, encounter transitions, action/contact agreement, healing and reset/persistence; recorded Simulator routes establish actual rendering and native input execution. Human playtests establish readability, control comfort, performance and enjoyment. Earlier green duel checks do not establish those outcomes for this changed prototype. Merge and TestFlight delivery keep their applicable authorisation and source-verification gates.
