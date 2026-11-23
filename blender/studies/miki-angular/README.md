# Miki angular static blockout

**Status:** Assigned static Blender review, 24 November 2026. The maintainer selected the [angular graphic direction](../../../art/characters/angular-study/README.md), then authorised a Miki blockout shown beside the concept and through camera B. This file tests proportions, colour planes and silhouette before rig fitting. It is not a final character, canonical replacement or runtime integration. Laura and Tom remain unchanged.

![Selected concept beside the actual static Blender blockout](comparison.png)

## Open and inspect

Open `miki-angular.blend`. Choose a scene from Blender's scene selector:

| Scene | Purpose |
|---|---|
| `01 Concept and angular blockout` | Default artist view: original Miki concept crop beside the static 3D figure |
| `02 Miki mesh editing` | Directly selectable character components at the origin, with a close artist camera |
| `03 Camera B exact phone scale` | Normal camera B projection at 926 × 428, with the character facing along the route |
| `04 High rear artist close-up` | Enlarged orthographic rear view at the same viewing angle; deliberately different from phone scale |

All scenes use one shared model collection; their instances do not maintain separate geometry. The concept card is a UV crop of the original generated sheet, not an edited bitmap or a character texture. Camera, card, labels, snow floor, lights and instances are review context outside the model collection. Saving this unregistered study does not export it into the app.

## Shape and construction

The blockout has a small tapered planar face, swept angular bob, long separated legs, a fitted teal coat, one broad diagonal ivory collar and two unequal coat points. A bent arm holds a diagnostic tablet while the other hand rests near the hip. The carrying strap follows the coat's surface. The pouch, tablet and stowed carbine are simple visual stand-ins; they do not change equipment rules or prove a runtime grip/muzzle location.

The saved model has **36 editable mesh parts, 938 triangles, 541 vertices and nine untextured matte materials**. Its native bounds are approximately **0.761 × 0.424 × 1.828 m**, including the static pose and carried props. The lowest sole vertex is at Z = 0. The parts are individually closed and intentionally overlap at clothing/body connections. Their assembly is for visual review; it is not yet connected deforming topology.

Every authored face uses flat normals and deliberately broad planes. There is no armature, skinning, animation, modifier, cloth simulation or custom runtime shader. A study palette approximates the selected illustration under linked bridge lighting: teal `#358F84`, teal shadow `#286C66`, teal light `#5B9E91`, ink `#30373C`, ivory `#CDCEBC`, ivory shadow `#A8AA9E`, skin `#CCA17D`, skin shadow `#A37F63` and leather `#594C40`. These local appearance choices and the count above do not change the current runtime palette or 400-triangle target. Budget and import validation precede integration.

## Camera comparison

![Close high rear artist view, not phone scale](high-rear.png)

The exact camera B scene uses Blender target **(0, 0, 0.95)**, eye **(0, −44, 56.95)**, perspective projection and **22° vertical field of view**. The model's native front is −Y; the route-facing instance rotates 180° around Z to face +Y, away from the camera. Resolution is **926 × 428 at 100%**, corresponding to the baseline phone's landscape point dimensions. The projected figure occupies about **11.81 × 18.57 render pixels** at that logical-size resolution. This establishes projection and scale, not successful physical-phone readability.

The [uncropped camera B render](camera-b.png) keeps that scale. The close high rear scene preserves the viewing direction within 0.000002°, but uses orthographic scale 2.6 to inspect shapes. Neither is a Simulator screenshot or a full bridge/HUD render. Facial marks cannot carry recognition at the exact framing; coat, collar, hair and colour need to do most of the work.

Additional views: [front](front.png), [side](side.png), [rear](rear.png).

## Verification and next gate

An independent read-only audit of the saved source confirms finite coordinates, no loose vertices or degenerate triangles, consistent flat shading and closed, consistently wound, positive-volume parts. It verifies the scene instances, exact camera B transform/lens/resolution, close rear angle, metre scale and absence of rigs or Actions. The relative concept image and bridge-light library resolve. A private/public resave comparison covers geometry, material assignments, normals, object transforms, scenes, instances and camera settings.

All 48 protected canonical/source/runtime/export fingerprints and the earlier Miki study remain unchanged. The existing **62 Blender/export tests pass**, including saved-file hygiene. Relative documentation links and Git LFS storage are checked. No app build, Simulator run, phone test, merge or release is included in this static authoring pass.

Review the silhouette and proportions before adding deforming topology or fitting the shared animations. The quiet face, angular sleeve caps and thin coat points remain rough blockout forms. Rig fitting must recheck foot contact, hand/weapon alignment, coat clearance and the new limb proportions; this static audit proves none of those motion properties. Physical-phone performance and visual acceptance remain unverified.

## Source and licence

- **Source:** Original Blender geometry authored for Lauder by Codex, guided by the selected AI-generated concept. No third-party mesh, rig, texture or animation was imported. The [concept's provenance](../../../art/characters/angular-study/README.md#generation-and-provenance) remains separate from the model's authorship.
- **Licence:** Original model and documentation under the project's [MIT licence](../../../LICENSE).
- **Storage:** Editable `.blend` source uses the format-wide Git LFS rule. PNGs larger than 1 MiB have explicit-path rules; smaller images remain ordinary Git. Render PNG metadata is removed with compressed pixels unchanged.
