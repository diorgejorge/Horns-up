# Inspect a multi-character OBJ sheet: loose-part bboxes + front/top renders.
# usage: blender -b --factory-startup -P inspect_sheet.py -- <obj> <out_dir> <tag>
import bpy, sys, os, json, math
from mathutils import Vector
src, out_dir, tag = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src)
ob = bpy.context.selected_objects[0]
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
parts = []
for o in bpy.context.scene.objects:
    if o.type != "MESH": continue
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = [round(min(v[i] for v in bb), 3) for i in range(3)]; mx = [round(max(v[i] for v in bb), 3) for i in range(3)]
    parts.append({"n": len(o.data.polygons), "min": mn, "max": mx})
parts.sort(key=lambda p: -p["n"])
allmn = Vector([min(p["min"][i] for p in parts) for i in range(3)]); allmx = Vector([max(p["max"][i] for p in parts) for i in range(3)])
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 1024; sc.render.resolution_y = 1024
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
c = (allmn + allmx) / 2; size = max(allmx - allmn) * 1.05
cam.data.type = "ORTHO"; cam.data.ortho_scale = size; cam.data.clip_end = size * 12
for view, loc, rot in (("front", (c.x, c.y - size * 3, c.z), (math.radians(90), 0, 0)),
                       ("top", (c.x, c.y, c.z + size * 3), (0, 0, 0))):
    cam.location = loc; cam.rotation_euler = rot
    sc.render.filepath = os.path.join(out_dir, f"{tag}_{view}.png"); bpy.ops.render.render(write_still=True)
print("INFO" + json.dumps({"nparts": len(parts), "bbox": [list(allmn), list(allmx)], "top": parts[:25],
                           "small_parts": len([p for p in parts if p["n"] < 200])}))
