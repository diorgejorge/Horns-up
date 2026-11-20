# Export split prep blends (from split_sheet.py) as static, textured GLBs: origin = base centre, Godot Y-up.
# usage: blender -b --factory-startup -P export_props.py -- <prep_dir> <out_dir> <prefix> <name1,name2,...>
import bpy, sys, os, json, math
from mathutils import Vector
prep_dir, out_dir, prefix, names = sys.argv[sys.argv.index("--") + 1:]
res = {}
for i, n in enumerate(names.split(","), 1):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(prep_dir, f"{n}_prep.blend"))
    ob = bpy.data.objects[n]
    out_name = f"{prefix}{i:02d}_{n}"
    ob.name = ob.data.name = out_name
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    co = [v.co for v in ob.data.vertices]
    mn = Vector([min(c[k] for c in co) for k in range(3)]); mx = Vector([max(c[k] for c in co) for k in range(3)])
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, out_name + ".glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_animations=False)
    res[out_name] = {"tris": len(ob.data.polygons), "size_xyz": [round(v, 2) for v in mx - mn],
                     "base_min": [round(v, 3) for v in mn]}
print("INFO" + json.dumps(res))
