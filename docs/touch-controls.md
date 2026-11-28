# Shared touch and controller controls

**Current scope:** the single-hero duel in [issue #236](https://github.com/RonildoBraga/lauder/issues/236). [Input bindings](prototype-plan.md#input-and-interaction-contract) are shared across touch, PS5/Xbox and keyboard.

Without an extended controller, the game exposes a movement stick, Attack, Guard, Dodge and a Focus/Unfocus toggle. Pause/Resume and a separate Restart target are available. An attached controller is preferred; **Use touch controls** selects touch explicitly and **Use controller** returns to the attached controller. Keyboard remains available for Simulator iteration. Focus is part of the [issue #238](https://github.com/RonildoBraga/lauder/issues/238) follow-up, which is not in the previously delivered TestFlight build47.

## Authority and capture

GameControls selects a source, samples hardware/captures and passes all raw state to InputRules. InputRules owns fresh edges and the neutral-release gate. Shared command priority is Pause → fresh Focus → Dodge → Guard → Attack. A fresh Focus consumes simultaneous Attack/Dodge requests while held Guard remains active. Combat owns focus selection, stamina and action legality; the touch surface cannot award hits or force an attack.

Each finger owns one zone and one generation until release/cancellation. Independent fingers may move and press an action together. A centred stick remains a contact: lifting every finger, not merely returning the vector to zero, clears the neutral gate. A rapid tap between samples is retained once. Source/lifecycle changes invalidate stale callbacks through generation tokens.

Pause keeps the capture surface mounted. Combat/focus zones stop accepting new actions, but captured fingers can release. Restart has its own target rather than repurposing a held Attack target. Paused/suppressed presses are consumed; Resume requires released input and does not replay them. Pause and source/lifecycle interruption preserve the selected focus; Retry and defeat clear it.

## Gameplay

Tap Focus once to turn towards the enemy while moving or guarding; tap Unfocus to return to free facing. A ground ring and the toggle state identify the selection. Turning is bounded, so it does not instantly catch an attack from behind. Holding Guard slows movement and protects the facing side; release it to recover stamina. Without focus, Guard holds the current facing. Attack is a fresh request, not automatic fire. Dodge is a fresh request with a limited protected interval; holding it cannot grant ongoing immunity. Focus never redirects or cancels an accepted attack or dodge.

## Validation limits

Native tests cover priority, source changes, stale generations, rapid taps, independent releases and a centred contact during Pause. The camera/focus revision passes the full check and all four recorded routes, including `duel-focus`; the [prototype plan](prototype-plan.md#camera-and-enemy-focus-follow-up--in-progress) records the exact source and results. Rendered Simulator tests use the shared input transaction. Pointer input does not prove physical multi-touch. Controller detection in Simulator does not prove live stick forwarding. A meaningful phone milestone must establish touch comfort, controller behaviour, recovery, audio and sustained performance.
