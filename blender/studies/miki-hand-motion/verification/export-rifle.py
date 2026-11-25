"""Export the separate static precision rifle for the native shooting review only."""
from pathlib import Path
import argparse,bpy,sys,json,hashlib
from pxr import UsdUtils,Sdf
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
source=args.source.expanduser().resolve();out=args.output.expanduser().absolute()
if out.exists() or out.is_symlink():raise ValueError('Output directory must be new')
if any(p.is_symlink() for p in out.parents):raise ValueError('Output ancestors must not be symbolic links')
out=out.resolve()
repository=next((p for p in source.parents if (p/'AGENTS.md').is_file()),None)
if repository:
 for name in ('blender','apple','art','docs','.git'):
  if out.is_relative_to(repository/name):raise ValueError('Use a scratch output outside authored source directories')
sha=hashlib.sha256(source.read_bytes()).hexdigest()
out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
bpy.ops.wm.usd_export(filepath=str(out/'character.usdc'),export_materials=True,generate_preview_surface=True,export_animation=False,
 export_lights=False,export_cameras=False,merge_parent_xform=False,convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',export_custom_properties=False)
assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(out/'character.usdc')),str(out/'character.usdz'))
assert hashlib.sha256(source.read_bytes()).hexdigest()==sha
(out/'record.json').write_text(json.dumps({'source':source.name,'source_sha256':sha,'usdz_sha256':hashlib.sha256((out/'character.usdz').read_bytes()).hexdigest()},indent=2)+'\n')
