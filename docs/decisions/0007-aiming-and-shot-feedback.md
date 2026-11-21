# ADR 0007 — Aiming and shot feedback

**Status:** Accepted\
**Date:** 21 November 2026\
**Amended:** 22 November 2026, when [ADR 0008](0008-weapon-feel-and-combat-plan.md) removed the aim line, made shots leave the way the leader faces, within a spread, and gave shots sound and vibration

## Context

On 21 November 2026 the maintainer asked for a better shooting system: **“I think we need to improve the shooting system to make combat feel more responsive, realistic, and satisfying. At the moment, I can't see the bullets or projectiles when firing, and the right joystick doesn't seem to allow me to aim.”** The request named five changes:
- **Right joystick aiming:** “The right joystick should control the direction the character aims, independently of movement, allowing for proper twin-stick shooter controls.”
- **Visible projectiles:** “Bullets or tracer effects should be visible so I can clearly see where I'm shooting.”
- **Environmental interaction:** “I should be able to shoot at walls and other surfaces, even when there are no enemies, so I can test the shooting mechanics and aiming accuracy.”
- **Shooting effects:** “muzzle flashes, bullet impacts, particle effects, and other visual feedback”, “consistent with our low-poly art style and mobile performance requirements”.
- **Camera adjustment:** “The camera currently feels too far away from the character. I'd like to bring it closer so combat is easier to see and aiming feels more precise.”

Until then, combat worked as [ADR 0004](0004-brooklyn-bridge-opening.md) set it out:
- **Aiming:** Fire shot the assisted target, the nearest hostile ahead in range and in sight. ADR 0004 says “There is no manual aiming on a phone”, and it turned down manual aiming with a second stick as hard on a phone.
- **The right stick:** nothing read it.
- **Firing at nothing:** with no target there was no shot, so nothing could strike a wall.
- **Tracers:** each lasted 0.08 s and was about 9 cm thick, which is barely two points tall on the phone from the 65 m camera.
- **The visual direction** says “No particles or postprocessing”, and that the camera “comes closer through its lens rather than by moving lower”.

The maintainer settled the three choices this left open:

| Question | The maintainer's choice |
| --- | --- |
| How should aiming work on touch, which has no right stick? | “Keep assisted aim (Recommended)” |
| Should practice shots outside a fight spend rounds? | “Free outside fights (Recommended)” |
| How should the camera come closer? | “Closer lens in fights (Recommended)” |

## Decision

### 1. The right stick aims

- **Controls:** on a controller, the right stick aims Miki's carbine apart from movement. In the Simulator, I, K, J and L do the same. Both go through InputRules, with the same release gate as every other control.
- **What aiming does:**
  - while the stick aims, Miki faces her aim, whichever way she walks;
  - aiming draws a holstered carbine, as a first Fire press does;
  - a thin amber line shows her aim out to where a shot would strike.
- **Fire** (R2, RT or F) shoots along the aim. A little help remains: a hostile within 8° of the aim, in reach and in sight, is hit.
- **Without the stick,** as on touch, Fire keeps ADR 0004's assisted aim. With no assisted target, it shoots straight ahead.
- **Only Miki carries the carbine,** so the weapon's controls show whenever she leads, in a fight or out of one, and only then.
- **Miki never fires first at someone.** A shot that would meet a hostile who is not yet a target holds. So before the stranger opens fire, she cannot shoot him, as ADR 0004 intends.

### 2. Shots strike the scenery

A shot that hits nobody flies on until a block stops it or the carbine's 14 m reach runs out. The blocks that stop it are those that rise above shoulder height, 1.25 m, and a salvage task's gate as it stands, so a shot flies over a low block. Hostiles' shots stop at cover as before.

### 3. Rounds

- **Outside an encounter,** a shot spends no round, so the aim can be tested anywhere without emptying the carbine before the bridge's first fight.
- **In an encounter,** every shot spends a round, even one that hits nobody, and puts the fight under way, as [ADR 0005](0005-squad-combat-experiment.md) has it.

### 4. What a shot looks like

Every shot, whether the leader's, a companion's, a scripted one or a hostile's, shows:
- **a streak** that flies from the shooter to where the shot strikes, at 80 m/s and up to 2.5 m long;
- **a flash** at the muzzle;
- **where it strikes a body,** a larger flash;
- **where it strikes a block,** a small flash, four chips flung back towards the shooter, and a mark that stays on the block for 4 s.

The party's shots are amber and hostiles' shots are the threat's red. Chips and marks are ink.

These are plain blocks in the palette's colours, sized by the marker scale so they read from the camera. They are made once, at load, and reused, so firing builds nothing, and only effects under way move each frame. This replaces the visual direction's “No particles” with these low-poly effects. It adds no particle systems or postprocessing.

### 5. A closer lens in a fight

- **When:** in an encounter, or while the right stick aims.
- **How:** the camera's lens narrows to 70% of the level's, about 14° from the bridge's 20°, easing there in about 0.3 s, and widens again for exploring. The camera keeps its height and angle, as the visual direction asks. A scripted scene keeps the level's lens for its framing.
- **Touch orders** map the screen to the ground through the lens as it is.

## Consequences

- **ADR 0004's assisted aim** remains the touch control. “There is no manual aiming on a phone” now holds for touch only.
- **D-pad orders** place their point ahead along the leader's heading ([ADR 0003](0003-squad-movement.md)). While Miki aims, that heading is her aim.
- **The fight's view is shorter:** in a fight the camera shows about 13 m ahead instead of about 19 m. Its lean towards the nearest hostile, up to 3 m, still applies. Whether the shooters stay in view is a question for play.
- **Starting values:** the help's 8°, the streak's speed and size, and the effects' sizes and times are all starting values, to tune in play.

## How it is judged

Simulator playtests come first, then the maintainer plays on the baseline iPhone with the PS5 controller and with touch. These questions decide it:
- Does the right stick aim responsively and precisely?
- Can you see where each shot goes, and does a strike on a wall read?
- Does the closer lens help in a fight, and do the shooters stay in view?
- Does the yard still hold 60 fps with the effects?

## Options considered

- **A touch aim stick:** a second stick under the right thumb, which fires while held. It would be more to build and tune, and it changes the touch layout.
- **Every shot spends a round:** more realistic, but the bridge's 12 rounds could run out before its first fight.
- **Free fire only in the combat yard:** the bridge and the salvage yard would keep the old rule.
- **A closer lens everywhere,** or a lower camera: the first changes exploring as well; the second changes the steep, high look.
- **Bullets with travel time:** hits would lag the trigger. A hit stays instant, and the streak shows its path.
- **RealityKit's particle emitters:** softer than the low-poly look, and dearer on the phone.

## What this does not settle

- Sound and haptics for shots.
- A touch aim stick.
- Laura's and Tom's weapons under the player's control.
- Recoil, reloading and weapon changes.
