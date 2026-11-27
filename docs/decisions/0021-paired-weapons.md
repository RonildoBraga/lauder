# ADR 0021 — Paired weapons

**Status:** Accepted, with starting values to tune in play; implemented in the [paired weapons](../prototype-plan.md#paired-weapons) pass, [PR #158](https://github.com/RonildoBraga/lauder/pull/158). Played on the phone in TestFlight build 32, where the maintainer said the weapons and controls feel right ([playtest](../prototype-plan.md#build-32-playtest)).

**Date:** 26 November 2026

**Damage revision, 27 November 2026:** The authorised [guard damage and feedback](../damage-feedback.md) revision retunes the weapon damage below and uses shared guard health with optional weak-point bonuses. The tables and consequences here retain PR #158's original starting values for comparison. The paired loadouts, controls, magazines, sword deflection and dome remain the basis of the implementation. [Explicit companion Attack/Defend](../companion-autonomy.md#attack-and-defend) supersedes the original leader-only firing consequence. Current source and verification belong to the [prototype plan](../prototype-plan.md#guard-damage-and-feedback--in-development).

## Assignment

The maintainer asked for each character to carry two weapons and switch between them: **“Also I want to change enhance the character mechanics so Miki can switch between a long range rifle high damage and close range rifle that can shoot multiple bulets rapid but middle range. Laura will be using a shotgun and can switch between a Jedi sword. Tom will be able to project a shield to protect him and its companions and he switches between the shield and a heavy M134 Minigun”**.

Asked how three open points should work, the maintainer chose these options:
- **Ammunition:** **“No shared count”**. Each weapon keeps its own magazine and reloads by itself, with no limit on spare rounds.
- **The sword:** **“Strike and block shots”**. Fire swings it at hostiles within about 1.5 m for heavy damage, and while it is out, shots from in front of Laura bounce off it.
- **The shield:** **“Dome that moves with him”**. Holding Fire keeps a dome round Tom as he walks slowly. He cannot shoot meanwhile, and it runs down in 6 s, then recharges.

All of this was said in a Claude session, which has no public permalink. The game calls the sword an **energy sword** and the gun a **minigun**: “Jedi” and “lightsaber” belong to Star Wars, and M134 is a real gun's designation.

This replaces the native weapons of [ADR 0010](0010-squad-weapons.md) and the [story bible](../story/story-bible.md#combat-identities)'s proposed carbine, burst weapon and scatter weapon.

## Decision

- **The pairs:** each traveller starts with the first of their pair in hand.

  | Who | First | Second |
  |---|---|---|
  | Miki | Long rifle | Assault rifle |
  | Laura | Shotgun | Energy sword |
  | Tom | Minigun | Shield dome |

- **Switching:**
  - Input: R1 on PS5 or RB on Xbox, freed by the controls pass; T on a keyboard; or the touch **Swap** button above Roll.
  - It needs a fresh press while exploring, and Dialogue and Pause consume it.
  - The other weapon comes into hand. If the first was drawn, the second is drawn after its own draw time.
  - Each weapon keeps its magazine, and a reload goes on while the weapon is put away. Restart returns everyone to their first weapon.
- **Ammunition:** rounds are not counted beyond each magazine. An empty magazine reloads by itself, the shared count and its “Out of ammunition” are gone, and the status shows only what is loaded.
- **The guns** (starting values; hits per shot against the guard's six):

  | Gun | Reach | Fire | Magazine | Reload | Hits |
  |---|---:|---|---:|---:|---:|
  | Long rifle | 22 m | One shot a second; very tight at rest, scattering on the move | 5 | 1.8 s | 3 |
  | Assault rifle | 12 m | Ten shots a second while held | 30 | 1.6 s | 1 |
  | Shotgun | 8 m | A wide blast every 0.9 s, worth one hit beyond its reach | 6 | 2 s | 3 |
  | Minigun | 14 m | Spins for 0.5 s, then about 16 shots a second with a wide scatter; Tom walks at 60% while it runs | 120 | 3 s | 1 |

- **The energy sword:**
  - Fire swings it every 0.55 s. A swing strikes every hostile who is a target, inside a 110° arc in front of Laura and within 1.6 m of their body, for three hits each.
  - Without the stick or a lock, Fire turns her towards the nearest target close by, as it turns a gun.
  - While she leads with it drawn, a hostile's shot from within 60° of her facing glances off the blade and hurts nobody. A shot from the side or behind still lands.
  - It has no magazine.
- **The shield dome:**
  - While Tom leads with it in hand and holds Fire, a dome of 2.6 m radius stands round him, wide enough for the Close formation's places.
  - A hostile's shot that would strike anyone inside the dome stops at its edge, if the shooter stands outside. Tom walks at 50% and cannot shoot.
  - It lasts 6 s of holding. Once it runs out it stays down until Fire is let go.
  - It recharges after 1 s, from empty to full in 6 s. A switch, a roll or a scene drops it.
- **Lock-on and aim:** the lock of [ADR 0020](0020-lock-on.md), the right stick and assisted aim work with every gun. The lock turns Laura towards her target for the sword.
- **Presentation:**
  - Each weapon has its own simple shape. Laura's blade glows in her colour, and Tom's dome is see-through in his colour, so no colour joins the palette.
  - Until the new weapons get sounds of their own, each borrows the nearest existing one. The long rifle uses the old carbine's shot, the assault rifle and the minigun the burst weapon's, and the shotgun the scatter weapon's. A swing is silent and its strikes are heard.
  - Vibration and the DualSense trigger follow the same mapping, and the sword and the shield leave R2 slack.

## Consequences

- The guard falls to two long-rifle shots, one shotgun blast and a swing, or a moment of minigun fire. Its fight, tuned for the old carbine and its twelve rounds, needs a playtest.
- The dome makes the guard's bursts harmless for as long as it lasts, and the sword does the same for Laura from the front.
- Companions still do not fire on their own; only the leader uses a weapon.
- R1 / RB, T and the touch layout's space above Roll are now taken.
- Dedicated sounds for the six weapons, the dome's own hum and a swing are left for a later pass.

## Verification

Recorded in the prototype plan under [Paired weapons](../prototype-plan.md#paired-weapons).
