# Shared touch and controller controls

**Current scope:** the single-hero duel in [issue #236](https://github.com/RonildoBraga/lauder/issues/236). [Input bindings](prototype-plan.md#input-and-interaction-contract) are shared across touch, PS5/Xbox and keyboard.

Without an extended controller, the game exposes a movement stick and Attack, Guard and Dodge. Pause/Resume and a separate Restart target are available. An attached controller is preferred; **Use touch controls** selects touch explicitly and **Use controller** returns to the attached controller. Keyboard remains available for Simulator iteration.

## Authority and capture

GameControls selects a source, samples hardware/captures and passes all raw state to InputRules. InputRules owns Pause priority, fresh edges and the neutral-release gate. Combat owns stamina and action legality; the touch surface cannot award hits or force an attack.

Each finger owns one zone and one generation until release/cancellation. Independent fingers may move and press an action together. A centred stick remains a contact: lifting every finger, not merely returning the vector to zero, clears the neutral gate. A rapid tap between samples is retained once. Source/lifecycle changes invalidate stale callbacks through generation tokens.

Pause keeps the capture surface mounted. Combat zones stop accepting new actions, but captured fingers can release. Restart has its own target rather than repurposing a held Attack target. Paused/suppressed presses are consumed; Resume requires released input and does not replay them.

## Gameplay

Hold Guard to protect the facing side and back away slowly. Release it to turn normally and recover stamina. Attack is a fresh request, not automatic fire. Dodge is a fresh request with a limited protected interval; holding it cannot grant ongoing immunity.

## Validation limits

Native tests cover priority, source changes, stale generations, rapid taps, independent releases and a centred contact during Pause. Rendered Simulator tests use the shared input transaction. Pointer input does not prove physical multi-touch. Controller detection in Simulator does not prove live stick forwarding. A meaningful phone milestone must establish touch comfort, controller behaviour, recovery, audio and sustained performance.
