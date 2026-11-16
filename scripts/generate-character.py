#!/usr/bin/env python3
"""Author Lauder's original Stage 1 mannequin and export its two USDZ clips.

No third-party Python packages or downloaded art. Requires macOS USD tools.
"""

import math
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "Sources/Content/Character"
SOURCE = ASSET / "source"

# Joint positions in the bind pose, in metres. Parents precede children.
JOINTS = [
    ("Root", (0, 0, 0)),
    ("Root/Hips", (0, .90, 0)),
    ("Root/Hips/Spine", (0, 1.10, 0)),
    ("Root/Hips/Spine/Chest", (0, 1.30, 0)),
    ("Root/Hips/Spine/Chest/Neck", (0, 1.44, 0)),
    ("Root/Hips/Spine/Chest/Neck/Head", (0, 1.59, 0)),
    ("Root/Hips/Spine/Chest/LeftArm", (-.29, 1.36, 0)),
    ("Root/Hips/Spine/Chest/LeftArm/LeftForearm", (-.29, 1.08, 0)),
    ("Root/Hips/Spine/Chest/LeftArm/LeftForearm/LeftHand", (-.29, .87, 0)),
    ("Root/Hips/Spine/Chest/RightArm", (.29, 1.36, 0)),
    ("Root/Hips/Spine/Chest/RightArm/RightForearm", (.29, 1.08, 0)),
    ("Root/Hips/Spine/Chest/RightArm/RightForearm/RightHand", (.29, .87, 0)),
    ("Root/Hips/LeftLeg", (-.11, .86, 0)),
    ("Root/Hips/LeftLeg/LeftShin", (-.11, .46, 0)),
    ("Root/Hips/LeftLeg/LeftShin/LeftFoot", (-.11, .10, 0)),
    ("Root/Hips/RightLeg", (.11, .86, 0)),
    ("Root/Hips/RightLeg/RightShin", (.11, .46, 0)),
    ("Root/Hips/RightLeg/RightShin/RightFoot", (.11, .10, 0)),
]

COLORS = {
    "Jacket": (.09, .32, .34),
    "Trousers": (.20, .24, .29),
    "Skin": (.67, .44, .29),
    "Dark": (.055, .065, .075),
    "Pack": (.40, .27, .13),
}

# Each box contributes mesh vertices weighted to an actual skeleton joint.
# This is one skinned Mesh, not a hierarchy of animated box transforms.
PARTS = [
    (1, (0, .89, 0), (.21, .10, .12), "Trousers"),
    (3, (0, 1.18, 0), (.22, .20, .12), "Jacket"),
    (4, (0, 1.425, 0), (.055, .05, .055), "Skin"),
    (5, (0, 1.60, 0), (.13, .16, .12), "Skin"),
    (5, (0, 1.735, .015), (.135, .035, .125), "Dark"),
    (5, (0, 1.59, -.14), (.025, .035, .025), "Skin"),
    (5, (-.05, 1.63, -.123), (.012, .012, .006), "Dark"),
    (5, (.05, 1.63, -.123), (.012, .012, .006), "Dark"),
    (3, (0, 1.18, .17), (.16, .19, .055), "Pack"),
]
for side, arm, leg in ((-1, 6, 12), (1, 9, 15)):
    PARTS.extend([
        (arm, (side * .29, 1.22, 0), (.065, .14, .075), "Jacket"),
        (arm + 1, (side * .29, .975, 0), (.055, .105, .065), "Jacket"),
        (arm + 2, (side * .29, .82, 0), (.055, .05, .065), "Skin"),
        (leg, (side * .11, .65, 0), (.09, .19, .09), "Trousers"),
        (leg + 1, (side * .11, .28, 0), (.075, .18, .075), "Trousers"),
        (leg + 2, (side * .11, .075, -.06), (.085, .075, .16), "Dark"),
    ])

FACES = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 4, 7, 3),
         (1, 2, 6, 5), (0, 1, 5, 4), (3, 7, 6, 2))
NORMALS = ((0, 0, -1), (0, 0, 1), (-1, 0, 0),
           (1, 0, 0), (0, -1, 0), (0, 1, 0))


def number(value):
    return f"{value:.7f}".rstrip("0").rstrip(".") if abs(value) > 1e-8 else "0"


def vector(values):
    return "(" + ", ".join(number(value) for value in values) + ")"


def array(values):
    return "[" + ", ".join(values) + "]"


def matrix(translation):
    return "((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), " + vector((*translation, 1)) + ")"


def local_positions():
    positions = dict(JOINTS)
    return [tuple(position[i] - positions.get(name.rpartition("/")[0], (0, 0, 0))[i]
                  for i in range(3)) for name, position in JOINTS]


def make_character():
    points, indices, normals, joint_indices = [], [], [], []
    subsets = {name: [] for name in COLORS}
    for joint, center, half, material in PARTS:
        start = len(points)
        points.extend(tuple(center[i] + sign[i] * half[i] for i in range(3))
                      for sign in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                                   (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)))
        subsets[material].extend(range(len(indices) // 4, len(indices) // 4 + 6))
        indices.extend(start + index for face in FACES for index in face)
        normals.extend(normal for normal in NORMALS for _ in range(4))
        joint_indices.extend([joint] * 8)

    assert len(joint_indices) == len(points) and max(joint_indices) < len(JOINTS)
    assert sorted(face for subset in subsets.values() for face in subset) == list(range(len(indices) // 4))
    text = '''#usda 1.0
(
    defaultPrim = "Character"
    metersPerUnit = 1
    upAxis = "Y"
)
def SkelRoot "Character" (kind = "component") {
    float3[] extent = [(-0.65, -0.1, -0.6), (0.65, 1.85, 0.6)]
    def Skeleton "Rig" (prepend apiSchemas = ["SkelBindingAPI"]) {
'''
    text += "        uniform token[] joints = " + array(f'"{name}"' for name, _ in JOINTS) + "\n"
    text += "        uniform matrix4d[] bindTransforms = " + array(matrix(pos) for _, pos in JOINTS) + "\n"
    text += "        uniform matrix4d[] restTransforms = " + array(matrix(pos) for pos in local_positions()) + "\n    }\n"
    text += '''    def Mesh "Body" (prepend apiSchemas = ["SkelBindingAPI", "MaterialBindingAPI"]) {
        uniform token subdivisionScheme = "none"
        uniform token orientation = "rightHanded"
        uniform token subsetFamily:materialBind:familyType = "partition"
        rel skel:skeleton = </Character/Rig>
        uniform token skel:skinningMethod = "classicLinear"
        matrix4d primvars:skel:geomBindTransform = ((1,0,0,0),(0,1,0,0),(0,0,1,0),(0,0,0,1))
'''
    text += "        point3f[] points = " + array(vector(point) for point in points) + "\n"
    text += "        int[] faceVertexCounts = " + array("4" for _ in range(len(indices) // 4)) + "\n"
    text += "        int[] faceVertexIndices = " + array(str(index) for index in indices) + "\n"
    text += "        normal3f[] normals = " + array(vector(normal) for normal in normals) + ' (interpolation = "faceVarying")\n'
    text += "        int[] primvars:skel:jointIndices = " + array(str(joint) for joint in joint_indices) + ' (interpolation = "vertex"; elementSize = 1)\n'
    text += "        float[] primvars:skel:jointWeights = " + array("1" for _ in points) + ' (interpolation = "vertex"; elementSize = 1)\n'
    for name, faces in subsets.items():
        text += f'''        def GeomSubset "{name}" (prepend apiSchemas = ["MaterialBindingAPI"]) {{
            uniform token elementType = "face"
            uniform token familyName = "materialBind"
            int[] indices = {array(str(face) for face in faces)}
            rel material:binding = </Character/Materials/{name}>
        }}
'''
    text += '    }\n    def Scope "Materials" {\n'
    for name, color in COLORS.items():
        text += f'''        def Material "{name}" {{
            token outputs:surface.connect = </Character/Materials/{name}/Surface.outputs:surface>
            def Shader "Surface" {{
                uniform token info:id = "UsdPreviewSurface"
                color3f inputs:diffuseColor = {vector(color)}
                float inputs:metallic = 0
                float inputs:roughness = 0.8
                token outputs:surface
            }}
        }}
'''
    return text + "    }\n}\n"


def pose(clip, phase):
    positions = local_positions()
    rotations = [(1, 0, 0, 0)] * len(JOINTS)
    angles = {}
    if clip == "Idle":
        positions[3] = (0, .20 + .004 * math.sin(phase), 0)
        angles[3] = ("z", .008 * math.sin(phase))
    else:
        stride = .44 * math.sin(phase)
        # Lower hips to keep the straight stance leg's foot on the floor.
        positions[1] = (0, .90 + .76 * (math.cos(stride) - 1), 0)
        angles[3] = ("z", .025 * math.sin(phase))
        for arm, leg, angle in ((6, 12, stride), (9, 15, -stride)):
            knee = -max(0, -angle / .44) * .60
            angles.update({arm: ("x", -.65 * angle), arm + 1: ("x", -.12),
                           leg: ("x", angle), leg + 1: ("x", knee),
                           leg + 2: ("x", -angle - knee)})
    for joint, (axis, angle) in angles.items():
        q = [math.cos(angle / 2), 0, 0, 0]
        q[1 if axis == "x" else 3] = math.sin(angle / 2)
        assert abs(sum(value * value for value in q) - 1) < 1e-12
        rotations[joint] = tuple(q)
    assert positions[0] == (0, 0, 0) and rotations[0] == (1, 0, 0, 0)
    return positions, rotations


def make_clip(clip):
    frames = 48 if clip == "Idle" else 24
    samples = list(range(0, frames + 1, 3))
    poses = [pose(clip, 2 * math.pi * frame / frames) for frame in samples]
    for first, last in zip(poses[0], poses[-1]):
        assert all(abs(a - b) < 1e-12 for x, y in zip(first, last) for a, b in zip(x, y))
    text = f'''#usda 1.0
(
    defaultPrim = "Character"
    startTimeCode = 0
    endTimeCode = {frames}
    timeCodesPerSecond = 24
    framesPerSecond = 24
    metersPerUnit = 1
    upAxis = "Y"
)
def SkelRoot "Character" (prepend references = @Character.usda@</Character>) {{
    over "Rig" {{
        rel skel:animationSource = </Character/Motion>
    }}
    def SkelAnimation "Motion" {{
        uniform token[] joints = {array(f'"{name}"' for name, _ in JOINTS)}
        half3[] scales = {array("(1, 1, 1)" for _ in JOINTS)}
'''
    for prop, kind, values in (("translations", "float3", [p[0] for p in poses]),
                               ("rotations", "quatf", [p[1] for p in poses])):
        text += f"        {kind}[] {prop}.timeSamples = {{\n"
        for frame, sample in zip(samples, values):
            text += f"            {frame}: {array(vector(value) for value in sample)},\n"
        text += "        }\n"
    return text + "    }\n}\n"


def flattened_content(path):
    result = subprocess.run(
        ["/usr/bin/usdcat", "--flatten", "--skipSourceFileComment", str(path)],
        check=True, capture_output=True, text=True,
    )
    # These Apple USD tools still emit the generated input-path documentation.
    # Ignore only that block, retaining authored metadata and scene content.
    return re.sub(
        r'^    doc = """Generated from Composed Stage of root layer [^\n]*\n"""\n',
        "", result.stdout, count=1, flags=re.MULTILINE,
    )


def export_matches(output, expected):
    if not zipfile.is_zipfile(output):
        return False
    check = subprocess.run(
        ["/usr/bin/usdchecker", "--arkit", "--strict", str(output)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if check.returncode:
        return False
    try:
        return flattened_content(output) == expected
    except subprocess.CalledProcessError:
        return False


def export_clip(source, output):
    expected = flattened_content(source)
    if export_matches(output, expected):
        print(f"{output.relative_to(ROOT)}: kept unchanged ({output.stat().st_size} bytes)")
        return

    # Packaging records ZIP timestamps. Validate a new candidate before replacing
    # a stale/invalid export, and preserve matching exports to avoid LFS churn.
    with tempfile.TemporaryDirectory(prefix=".character-export-", dir=ASSET) as directory:
        candidate = Path(directory) / output.name
        subprocess.run(
            ["/usr/bin/usdzip", "--arkitAsset", str(source), str(candidate)], check=True,
        )
        subprocess.run(
            ["/usr/bin/usdchecker", "--arkit", "--strict", str(candidate)], check=True,
        )
        if flattened_content(candidate) != expected:
            raise RuntimeError(f"Packaged content differs from {source.name}; export left unchanged")
        candidate.replace(output)
    print(f"{output.relative_to(ROOT)}: exported ({output.stat().st_size} bytes)")


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / "Character.usda").write_text(make_character(), encoding="utf-8")
    for clip in ("Idle", "Walk"):
        source = SOURCE / f"{clip}.usda"
        output = ASSET / f"{clip}.usdz"
        source.write_text(make_clip(clip), encoding="utf-8")
        subprocess.run(["/usr/bin/usdcat", "--loadOnly", str(source)], check=True)
        subprocess.run(["/usr/bin/usdchecker", "--strict", str(source)], check=True)
        export_clip(source, output)
    print(f"{len(JOINTS)} joints; {len(PARTS) * 8} vertices; {len(PARTS) * 6} quads")


if __name__ == "__main__":
    main()
