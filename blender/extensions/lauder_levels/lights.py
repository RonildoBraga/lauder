"""The level's lights: Blender's suns, point lights and spot lights as the game's, within the visual
direction's budget."""

import math
from dataclasses import dataclass

from .common import _collection, from_blender, LayoutError, LIGHTS, _srgb, _unit, Vector


#: The visual direction's budget (docs/visual-direction.md): at most four lights since the
#: maintainer's choice of 19 November 2026, with at most one casting shadows.
MOST_LIGHTS = 4
MOST_SHADOWED_LIGHTS = 1
#: The shadow distance a light gets when its shadow is turned on in Blender.
DEFAULT_SHADOW_DISTANCE = 25
#: Blender's sun strength, in W/m², for each lux of a game light. Blender and RealityKit render
#: differently, so this only brings Blender's preview close; the game shows the real result.
SUN_STRENGTH_PER_LUX = 1 / 700
#: How far from the origin the layout file puts a light's source. Only its direction matters.
SOURCE_LENGTH = 10
#: Lumens for each watt of a Blender point or spot light: 683 lm/W, the luminous efficacy that
#: defines the candela. As with the sun, the game shows the real result.
LUMENS_PER_WATT = 683
#: How far along a spot light's beam the layout file puts the point it shines towards.
TARGET_LENGTH = 10


@dataclass
class Light:
    """A light on the level: a sun, as far away as the sun and shining from one direction over the
    whole level; a point light; or a spot light."""
    name: str
    #: For a sun, a point in the direction the light comes from, (x, y, z): only the direction
    #: matters. None for a point or spot light.
    source: tuple
    #: In sRGB, each channel from 0 to 1.
    color: tuple
    #: In lux for a sun, and in lumens for a point or spot light.
    intensity: float
    #: For a sun, how far from the camera its shadows reach, in metres, or None when it casts none.
    shadow_distance: float = None
    #: sun, point or spot.
    kind: str = "sun"
    #: For a point or spot light: where it stands, (x, y, z), and how far it reaches, in metres.
    position: tuple = None
    radius: float = None
    #: For a spot light: a point it shines towards, (x, y, z); the full-strength and outer widths
    #: of its cone, in degrees; and whether it casts the level's shadow.
    target: tuple = None
    angles: tuple = None
    shadow: bool = False

    @property
    def casts_shadows(self):
        return self.shadow_distance is not None if self.kind == "sun" else self.shadow


def _light_problems(lights):
    """The visual direction's budget for lights, and lights the game can use."""
    problems = []
    if not lights:
        problems.append("The level needs a light.")
    if len(lights) > MOST_LIGHTS:
        problems.append(
            f"The visual direction allows at most {MOST_LIGHTS} lights, not {len(lights)}.")
    shadowed = [light.name for light in lights if light.casts_shadows]
    if len(shadowed) > MOST_SHADOWED_LIGHTS:
        problems.append(
            f"The visual direction allows {MOST_SHADOWED_LIGHTS} light with shadows, but "
            f"{len(shadowed)} cast them: {', '.join(shadowed)}.")
    for light in lights:
        if light.intensity <= 0:
            problems.append(f"{light.name} needs some intensity.")
        if any(not 0 <= value <= 1 for value in light.color):
            problems.append(f"{light.name}'s colour channels should be between 0 and 1.")
        if light.kind == "sun":
            if light.shadow_distance is not None and light.shadow_distance <= 0:
                problems.append(f"{light.name}'s shadow distance should be more than 0.")
            if all(abs(value) < 1e-6 for value in light.source):
                problems.append(f"{light.name} needs a direction to shine from.")
            continue
        if light.radius is None or light.radius <= 0:
            problems.append(f"{light.name} should reach further than 0 m.")
        if light.kind == "spot":
            inner, outer = light.angles
            if not 0 < outer <= 180 or not 0 <= inner <= outer:
                problems.append(f"{light.name}'s cone should open between 0° and 180°.")
            if all(abs(a - b) < 1e-6 for a, b in zip(light.position, light.target)):
                problems.append(f"{light.name} needs a direction to shine in.")
    return problems


@dataclass
class LightShape:
    """What Export reads from one Blender light."""
    name: str
    #: Blender's kind of light: SUN, POINT, SPOT or AREA.
    kind: str
    #: Where the light comes from, as a unit vector in Blender's space: the light's own +z. A spot
    #: light shines the other way.
    direction: tuple
    #: Scene-linear RGB, as Blender holds it.
    color: tuple
    #: Blender's strength: in W/m² for a sun, and in W for a point or spot light.
    energy: float
    shadow: bool
    #: The shadow distance kept on the light, if it has one.
    shadow_distance: float = None
    #: Where the light stands, in Blender's space.
    position: tuple = (0, 0, 0)
    #: Blender's Custom Distance: whether it is on, and how far the light reaches with it.
    custom_distance: bool = False
    cutoff: float = 40.0
    #: A spot light's cone: its full width in radians, and how soft its edge is, from 0 to 1.
    spot_size: float = 0.0
    spot_blend: float = 0.0
    #: Blender's Exposure, which multiplies the strength by 2^exposure; Normalize, which keeps the
    #: light's power the same at any size; and whether Temperature sets its colour.
    exposure: float = 0.0
    normalize: bool = True
    temperature: bool = False


def spot_inner_angle(spot_size, spot_blend):
    """The full width, in degrees, of the cone in which a Blender spot light shines at full
    strength. Blender fades it over the outer `spot_blend` of the cone's cosine range."""
    edge = math.cos(spot_size / 2)
    return 2 * math.degrees(math.acos(min(1.0, edge + (1 - edge) * spot_blend)))


def lights_from_shapes(shapes):
    """The layout's lights from Blender's, and anything that stops an export."""
    lights, problems = [], []
    for shape in shapes:
        if shape.temperature:
            problems.append(f"{shape.name} takes its colour from Temperature, which the game does "
                            f"not read: turn Temperature off and set its Color instead.")
            continue
        if not shape.normalize:
            problems.append(f"{shape.name} has Normalize off, so Blender makes it brighter as it "
                            f"grows, and the game does not: turn Normalize on.")
            continue
        energy = shape.energy * 2 ** shape.exposure
        colour = tuple(round(value, 3) for value in _srgb(shape.color))
        if shape.kind == "SUN":
            source = tuple(round(value * SOURCE_LENGTH, 2)
                           for value in _unit(from_blender(shape.direction)))
            intensity = round(energy / SUN_STRENGTH_PER_LUX, 1)
            shadow = (shape.shadow_distance or DEFAULT_SHADOW_DISTANCE) if shape.shadow else None
            lights.append(Light(shape.name, source, colour, intensity, shadow))
            continue
        if shape.kind not in ("POINT", "SPOT"):
            problems.append(f"{shape.name} is an {shape.kind.lower()} light; the game has sun, "
                            f"point and spot lights.")
            continue
        kind = shape.kind.lower()
        if kind == "point" and shape.shadow:
            problems.append(f"{shape.name} is a point light with its shadow on, and the game draws "
                            f"no shadows from point lights: turn its shadow off.")
            continue
        if not shape.custom_distance:
            problems.append(f"{shape.name} needs its Custom Distance on: the game's {kind} light "
                            f"reaches only that far, as Blender's preview then does.")
            continue
        position = tuple(round(value, 3) for value in from_blender(shape.position))
        intensity = round(energy * LUMENS_PER_WATT, 1)
        radius = round(shape.cutoff, 3)
        if kind == "point":
            lights.append(Light(shape.name, None, colour, intensity, kind="point",
                                position=position, radius=radius))
            continue
        beam = _unit(from_blender(tuple(-value for value in shape.direction)))
        target = tuple(round(p + b * TARGET_LENGTH, 3) for p, b in zip(position, beam))
        angles = (round(spot_inner_angle(shape.spot_size, shape.spot_blend), 2),
                  round(math.degrees(shape.spot_size), 2))
        lights.append(Light(shape.name, None, colour, intensity, kind="spot", position=position,
                            radius=radius, target=target, angles=angles, shadow=shape.shadow))
    return lights, problems


def lights_from_blender():
    """What Export reads from the level's lights."""
    part = _collection(LIGHTS)
    if part is None:
        return []
    shapes = []
    for item in part.all_objects:
        if item.type != "LIGHT":
            raise LayoutError(f"{item.name} is in Lights but is not a light.")
        data = item.data
        direction = item.matrix_world.to_quaternion() @ Vector((0, 0, 1))
        distance = data.get("lauder_shadow_distance")
        shapes.append(LightShape(
            item.name, data.type, tuple(direction), tuple(data.color), data.energy,
            data.use_shadow, None if distance is None else float(distance),
            position=tuple(item.matrix_world.translation),
            custom_distance=data.use_custom_distance, cutoff=data.cutoff_distance,
            spot_size=getattr(data, "spot_size", 0.0), spot_blend=getattr(data, "spot_blend", 0.0),
            exposure=data.exposure, normalize=data.normalize, temperature=data.use_temperature))
    return shapes


def lights_outside_the_level(view_layer):
    """The visible lights that are not in the level's Lights, such as the one in Blender's default
    scene. Game Look would show them, but the game has no such light."""
    part = _collection(LIGHTS)
    own = set(part.all_objects) if part is not None else set()
    return [item.name for item in view_layer.objects
            if item.type == "LIGHT" and item not in own and item.visible_get(view_layer=view_layer)]
