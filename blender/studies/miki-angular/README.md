# Miki navigator and sniper pose study

**Status:** Assigned Blender review, 24 November 2026. The maintainer selected the [angular graphic direction](../../../art/characters/angular-study/README.md), agreed Miki's [field navigator/explorer role](../../../docs/story/story-bible.md#tablet-and-field-navigation), then clarified that she is a sniper who can use different sniper rifles. This source develops her field slate, rifle family and four static poses. Her body remains a rough blockout awaiting visual review; Laura and Tom are unchanged. The study is unregistered and does not export into the app.

![Four actual Blender poses: inspection, lowered carry, secure stow and weapon ready](poses.png)

## Open and inspect

Open `miki-angular.blend`. Choose a scene from Blender's scene selector:

| Scene | Purpose |
|---|---|
| `01 Tablet role poses` | Default four-pose gallery, with labels and shared bridge lighting |
| `02 Inspection model` | Directly selectable inspection components at the origin |
| `03 Lowered carry model` | One-handed carry using the rear grip |
| `04 Stowed model` | Vertical slate in its holster, hands free |
| `05 Weapon ready model` | Holstered slate and two hands on the new precision rifle, in low-ready carry |
| `06 Concept comparison` | Original concept crop beside the inspection pose |
| `07 Camera B exact phone scale` | Normal camera B projection at 926 × 428, facing along the route |
| `08 High rear artist close-up` | Enlarged orthographic rear view at the same viewing angle |
| `09 Field slate detail` | Front and back of the shared device without the character |
| `10 Sniper rifle family` | Side-profile design comparison of scout, precision and heavy rifle options |

The four pose collections share the unchanged body and prop mesh data. Arms use separate static geometry with equal segment lengths across poses; head and prop transforms vary. Gallery instances and the device detail reuse those data rather than maintaining another model. The concept card is a UV crop of the original generated sheet, not a character texture. Cameras, labels, floor, lights and contact markers are review context outside the character geometry.

## Field slate and carrying arrangement

![Front and back of the landscape field slate](tablet-detail.png)

The slate uses a compact landscape case, clipped corner, matte inset, two broad map marks, a physical control and rear grip. Its **case measures 0.185 × 0.125 × 0.026 m**; the rear handle adds depth beyond the case. It uses the existing palette, without screen emission, text or functional interface. The broad marks suggest field records at artist scale; tiny graphics cannot establish its identity at camera B.

The device rotates vertically into the existing hip-pouch location. The case seats on the floor, with about **22.5 mm exposed above the lip**. A **40 mm open channel** in the holster front clears the rear grip mounts; the back, side strips and floor support the slate. The broad retainer is folded down when the device is held and closed above it when stowed. These are separate static shapes, not a demonstrated opening animation.

| Pose | Visual intent |
|---|---|
| Inspection | Both hands support the slate below the collar; the display faces Miki and her head inclines towards it |
| Lowered carry | One hand holds the rear grip outside the coat, with the display facing her leg |
| Secure stow | The same slate is vertical behind the retainer; both hands are free |
| Weapon ready | The slate remains holstered, both hands meet the rifle and the stock contacts the upper coat below the collar; there is no duplicate back weapon |

The role extends technical inspection and purposeful salvage. The [first-tower observation vignette](../../../docs/gameplay-script.md#mikis-tablet-exploration-vignette-proposal) remains a proposed gameplay example. This pass establishes no new map screen, control, scanner, hacking ability or runtime attachment rule.

## Sniper rifle family

![Three original rifle design options](rifle-family.png)

The [sniper direction](../../../docs/story/story-bible.md#sniper-rifle-family) retains Miki's patient observation and precision/disruption role. The three visual options use the same broad design language: tapered shoulder stock and cheek comb, shaped receiver and grip, faceted fore-end, a separated slim barrel and one low-mounted scope. Charcoal, slate and a restrained teal mark keep them consistent with her clothing and field equipment. The scope's front is matte rather than emissive.

| Visual option | Authored shape | Proposed distinction, not implemented balance |
|---|---|---|
| Scout | Shorter barrel, narrower fore-end and smaller optic; about 0.90 m overall | Lighter handling and faster recovery |
| Precision | Medium scope and full fore-end; about 1.06 m overall; used in the four poses | Deliberate, balanced long-range shots |
| Heavy | Deeper receiver, substantial shroud and boxier optic; about 1.17 m overall | Slower anti-machine option |

These are alternative compatible rifles, with one equipped at a time. The source supplies shared local stock, grip, support, scope and muzzle markers for comparing the designs; the selected precision rifle's mesh data are shared across the four poses. Other variants have not been fitted to the hands or animated. Acquiring, selecting and balancing them remain design work.

The precision rifle replaces the earlier three-piece gun throughout this study. While Miki inspects or carries the tablet, the rifle lies along the existing back sling with a small keeper linking the assembly. That keeper is a static attachment study, not a validated sling or draw mechanism. In the ready pose, the tablet stays secured and the stock is supported against the coat below the tall collar. This is **low-ready**, below her eyes. A convincing scoped aiming pose still needs head, neck, shoulder, cheek and eye-relief work, followed by recoil and transition checks. It is not established by adding an optic to a static gun.

The built bridge retains its current carbine, assisted/manual aim, ammunition, damage and controls. No runtime rifle swap, scope view, equipment interface or new weapon rule is included here.

## Model construction

![Selected concept beside the inspection blockout](comparison.png)

The small tapered face, swept angular bob, long separated legs, teal wrap coat, broad diagonal ivory collar and unequal coat points remain the preceding blockout's forms. The body, head, tablet and holster from the field-device pass are preserved. This pass replaces the study weapon, adds the sling keeper and refits the ready arms; its contact remains an authoring approximation pending rig fitting.

Each pose has **57 editable mesh parts, 1,446 triangles, 837 vertices and ten untextured matte materials**. These counts include clothing and carried equipment, but exclude review context and the separate rifle-family comparison. Parts are individually closed and intentionally overlap at body/clothing connections; this is not connected deforming topology. Shared data do not multiply the per-character count. The initial blockout at `4ac20ea` had 36 parts and 938 triangles; the field-device pass at `c0e2d56` had 47 parts and 1,222 triangles.

Faces use flat normals and broad planes. There is no armature, skinning, Action, modifier, cloth simulation or custom runtime shader. The clothing/device palette remains teal `#358F84`, teal shadow `#286C66`, teal light `#5B9E91`, ink `#30373C`, ivory `#CDCEBC`, ivory shadow `#A8AA9E`, skin `#CCA17D`, skin shadow `#A37F63` and leather `#594C40`; the rifle adds matte slate `#626C70`. These study choices do not change the current runtime palette or 400-triangle target. Budget and import validation precede integration.

## Camera comparison

![Close high rear artist view, not phone scale](high-rear.png)

The exact camera B scene retains target **(0, 0, 0.95)**, eye **(0, −44, 56.95)**, perspective projection and **22° vertical field of view**. The model's native front is −Y; the route-facing instance rotates 180° around Z to face +Y, away from the camera. Resolution is **926 × 428 at 100%**, with square pixels, corresponding to the baseline phone's landscape point dimensions.

The inspection figure still projects to approximately **11.32 × 18.79 render pixels**. The [uncropped camera B render](camera-b.png) establishes projection and scale, not successful physical-phone readability. The high rear close-up preserves its viewing direction but uses orthographic scale 2.6 to inspect shapes. Neither image is a Simulator screenshot or full bridge/HUD render. Coat, collar, hair, gesture and the rifle's broad silhouette must carry recognition at the distant framing.

Additional inspection views: [front](front.png), [side](side.png), [rear](rear.png). Individual pose views: [inspection](inspection.png), [lowered carry](lowered-carry.png), [stowed](stowed.png), [weapon ready](weapon-ready.png).

## Verification and next gate

The saved source passes an independent read-only geometry, preservation, rifle-fit and camera audit: finite, nondegenerate, closed, consistently wound, positive-volume, flat-shaded meshes; ten matte materials; and no rig or Actions. All six static contact pairs pass, including the ready hands and stock-to-coat support. Arm segment lengths are preserved. The equipped precision rifle clears the collar, tablet and holster in the sampled poses, and each character has one rifle assembly. Scope and muzzle direction, the device's seating and its grip-channel clearance pass. These checks do not prove anatomical finger grip, continuous draw/stow motion, scoped aiming, full self-collision clearance or shared-skeleton compatibility.

The public source matches the audited private candidate, including all three rifle templates. Its relative concept image and bridge-light library resolve, and its saved default is the four-pose gallery. All **176 preserved body, head, tablet and holster objects**, **48 protected canonical/source/runtime/export fingerprints** and the earlier rounded study remain unchanged. The existing **62 Blender/export tests pass** on the rifle revision, including saved-file hygiene. Documentation links, whitespace, image metadata/pixel preservation and Git LFS storage are checked. Actual Blender views accompany the source.

Review the device, carrying arrangement and poses before fitting deforming topology or the shared animations. The face, angular sleeve caps and thin coat points remain rough. Later motion work must recheck foot contact, coat clearance, hand/weapon alignment and transitions. Physical-phone performance and final visual acceptance remain unverified. No app build, Simulator run, phone test, merge or release is included in this authoring pass.

## Source and licence

- **Source:** Original Blender geometry authored for Lauder by Codex, guided by the selected AI-generated concept. No third-party mesh, rig, texture or animation was imported. The [concept's provenance](../../../art/characters/angular-study/README.md#generation-and-provenance) remains separate from the model's authorship.
- **Licence:** Original model and documentation under the project's [MIT licence](../../../LICENSE).
- **Storage:** Editable `.blend` source uses the format-wide Git LFS rule. PNGs larger than 1 MiB have explicit-path rules; smaller images remain ordinary Git. Render PNG metadata is removed with compressed pixels unchanged.
