# Touch controls

The bridge can be played with the touch screen alone, for when no controller is at hand.

## Behaviour

Without an extended controller, show a fixed bottom-left analog stick plus **Look**, **Fire**, **Roll** beside Fire, **Swap: weapon** above Roll and Fire, **Next: name**, **Formation** and **Pause/Resume**. The three travel together from the start, so Next and Formation always show. With a controller attached, prefer it unless **Use touch controls** is selected; **Use controller** returns to it. The preference lasts for the run, not across launches.

Look makes the leader look around; it reads Continue during dialogue and Restart while paused. Fire uses the leader's weapon in hand at its pace ([ADR 0021](decisions/0021-paired-weapons.md)). Miki has a long rifle and an assault rifle, Laura a shotgun and an energy sword that she swings, and Tom a minigun and a shield dome that stays up while Fire is held. **Swap** brings the other weapon into hand and names it. Assistance turns the leader towards a clear target before firing; otherwise the shot follows their facing. Rounds are not counted beyond the magazine: magazines reload automatically, keep their state across switches and freeze on Pause. Practice outside a fight deals no hits.

Roll makes the leader [dodge-roll](decisions/0019-dodge-roll.md) 3 m the way the stick points, or the way they face with the stick centred; hostile shots pass through them while they roll. It shows only while exploring, so it never covers a conversation's lines. It needs a fresh press, does not fire, and waits half a second after a roll before the next.

Next switches leadership once per press without changing positions. Formation cycles Close, Spread and Column; after a position order it reads Follow and calls companions back. Hold on open ground for about a third of a second to open the order menu. Lift on Both to send both, slide left/right to send that member or down to Hold. Slide upper-left for **Attack** or upper-right for **Defend**; straight up, lifting before the menu opens or moving more than about 12 points first cancels. The camera ray fixes the marked ground point when the menu opens. An unreachable position destination gives a brief red cross; accepted destinations show each companion's ring. Attack/Defend change stance without needing a reachable point.

The [review follow-up](prototype-plan.md#claude-review-follow-ups--in-development) measures slides from where the finger first touched, even when the menu artwork is clamped at an edge. Return within 30 points of that start to restore Both; straight upward travel has a wider cancel sector. Start the hold far enough below the top edge to leave room for upward cancel and stance gestures. Extremely high presses cannot provide that travel; sideways selection and returning to Both remain safe. The original marked ground point is retained. These source changes are not yet in the delivered build 36.

The squad starts in Defend and the HUD names the current stance. Fire controls only the selected leader; it never grants companions permission to attack. After an explicit Attack order they may use their native roles against the guard. Defend stops companion attacks, cancels existing position orders and recalls them toward the leader using nearby legal cover. The stance persists across leader changes, while Retry/Restart returns to Defend. Position orders given afterward remain non-firing unless Attack is selected.

Pause keeps Resume at the top right, Look reads Restart and Vibration switches On/Off. There is no scene selector, test-weapon choice, Signature, Regroup action or [lock-on](decisions/0020-lock-on.md): Fire's assisted aim picks the target. The status panel stays visible with touch. Controller/keyboard equivalents are in the [input contract](prototype-plan.md#input-and-interaction-contract).

## Input ownership

TouchInput supplies raw values to GameControls and InputRules. It never calls session or world actions directly. Every control tracks its own finger, allowing movement beside a held Fire or tapped Next/Look. Quick taps latch until the next input sample.

Source changes and inactivity cancel captures through generation tokens. Stale callbacks cannot affect a new capture. Pause leaves the capture surface mounted so every contact remains visible to the neutral-input gate. All fingers must lift before resuming, including a centred-stick finger. A press keeps the intent it began with until release, so an action held before Pause cannot turn into Restart.

The screen stays awake while Lauder is active in the foreground, including Pause, and restores normal idle locking when leaving.

## Checking

Earlier physical checks on iPhone 13 Pro Max verified simultaneous stick/button touches, one switch per press, stopping on release, Pause with held fingers and background recovery. They predate the bridge-only reset and do not establish its current behaviour. Shared rules and pointer-driven Simulator checks exercise presentation and routing; they do not establish multi-touch, controller handover, haptics or phone performance. Xbox hardware remains unverified.

The [prototype plan](prototype-plan.md#deferred-phone-and-playtest-checks) records deferred physical checks. TestFlight availability is distinct from installation, playtesting and enjoyment. Use Simulator for daily iteration and perform a physical checkpoint when agreed.
