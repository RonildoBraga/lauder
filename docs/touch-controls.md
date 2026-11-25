# Touch controls

The bridge can be played with the touch screen alone, for when no controller is at hand.

## Behaviour

Without an extended controller, show a fixed bottom-left analog stick plus **Look**, **Fire**, **Roll** beside Fire, **Next: name** when a companion has joined, **Formation** when two have joined, and **Pause/Resume**. With a controller attached, prefer it unless **Use touch controls** is selected; **Use controller** returns to it. The preference lasts for the run, not across launches.

Look requests the shared contextual action: Search, Help, Continue during dialogue and Restart while paused. Fire draws the current leader's native weapon and holds fire at its pace; Miki has a carbine, Laura a burst weapon and Tom a close scatter weapon. Assistance turns the leader towards a clear target before firing; otherwise the shot follows their facing. Practice is free; actual leader shots during encounters spend shared ammunition. Magazines reload automatically, retain readiness across switches and freeze on Pause.

Roll makes the leader [dodge-roll](decisions/0019-dodge-roll.md) 3 m the way the stick points, or the way they face with the stick centred; hostile shots pass through them while they roll. It needs a fresh press, does not fire, and waits half a second after a roll before the next.

Next switches leadership once per press without changing positions. Formation cycles Close, Spread and Column; after an order it reads Follow and calls companions back. Once both companions have joined, hold on open ground for about a third of a second to open the order menu. Lift on Both to send both, slide left/right to send that member or down to Hold. Slide up, lift before the menu opens or move more than about 12 points first to cancel. The camera ray fixes the marked ground point when the menu opens. An unreachable destination gives a brief red cross; accepted destinations show each companion's ring.

Pause keeps Resume at the top right, Look reads Restart and Vibration switches On/Off. There is no scene selector, test-weapon choice, Signature or Regroup action. The status panel stays visible with touch. Controller/keyboard equivalents are in the [input contract](prototype-plan.md#input-and-interaction-contract).

## Input ownership

TouchInput supplies raw values to GameControls and InputRules. It never calls session or world actions directly. Every control tracks its own finger, allowing movement beside a held Fire or tapped Next/Look. Quick taps latch until the next input sample.

Source changes and inactivity cancel captures through generation tokens. Stale callbacks cannot affect a new capture. Pause leaves the capture surface mounted so every contact remains visible to the neutral-input gate. All fingers must lift before resuming, including a centred-stick finger. A press keeps the intent it began with until release, so an action held before Pause cannot turn into Restart.

The screen stays awake while Lauder is active in the foreground, including Pause, and restores normal idle locking when leaving.

## Checking

Earlier physical checks on iPhone 13 Pro Max verified simultaneous stick/button touches, one switch per press, stopping on release, Pause with held fingers and background recovery. They predate the bridge-only reset and do not establish its current behaviour. Shared rules and pointer-driven Simulator checks exercise presentation and routing; they do not establish multi-touch, controller handover, haptics or phone performance. Xbox hardware remains unverified.

The [prototype plan](prototype-plan.md#deferred-phone-and-playtest-checks) records deferred physical checks. TestFlight availability is distinct from installation, playtesting and enjoyment. Use Simulator for daily iteration and perform a physical checkpoint when agreed.
