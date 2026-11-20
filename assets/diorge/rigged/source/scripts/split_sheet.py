# Split a multi-character OBJ sheet into one <name>_prep.blend per character (keeps UV + material),
# one uniform scale for the whole sheet (relative sizes kept), decimate, reference renders.
# usage: blender -b --factory-startup -P split_sheet.py -- <obj> <out_dir> <json: [[name, x_center], ...]> <tallest_m> <tris>
import bpy, sys, os, json, math
from mathutils import Vector, Matrix
src, out_dir, spec, tallest, tris = sys.argv[sys.argv.index("--") + 1:]
spec = json.loads(spec); tris = int(tris)
fixed_scale = float(tallest[1:]) if tallest.startswith("x") else None  # "x2.628" = reuse another sheet's factor
tallest = None if fixed_scale else float(tallest)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src)
ob = bpy.context.selected_objects[0]
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]

def bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return (Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)]))

groups = {e[0]: [] for e in spec}
for p in parts:
    if len(p.data.vertices) < 50: bpy.data.objects.remove(p); continue  # stray verts
    lo, hi = bbox([p]); cx = (lo.x + hi.x) / 2
    n = min(spec, key=lambda s: abs(s[1] - cx))[0]  # nearest character centre along X
    groups[n].append(p)

zmin = min(bbox(g)[0].z for g in groups.values()); zmax = max(bbox(g)[1].z for g in groups.values())
s = fixed_scale or tallest / (zmax - zmin)
report = {}
for n, objs in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = o.data.name = n
    lo, hi = bbox([o])
    o.data.transform(o.matrix_world); o.matrix_world = Matrix()
    rz = math.radians(dict((e[0], e[2]) for e in spec if len(e) > 2).get(n, 0))  # optional yaw fix, degrees
    o.data.transform(Matrix.Rotation(rz, 4, "Z") @ Matrix.Scale(s, 4)
                     @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
    lo, hi = bbox([o])  # re-centre after the yaw
    o.data.transform(Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
    nt = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if nt > tris * 1.25:
        bpy.context.view_layer.objects.active = o
        dm = o.modifiers.new("dec", "DECIMATE"); dm.ratio = tris / nt
        bpy.ops.object.modifier_apply(modifier="dec")
    lo, hi = bbox([o])
    report[n] = {"parts": len(objs), "tris_in": nt, "faces": len(o.data.polygons),
                 "size": [round(v, 3) for v in (hi - lo)]}

tmp = os.path.join(out_dir, "sheet_split_tmp.blend")
bpy.ops.wm.save_as_mainfile(filepath=tmp)
for n in groups:  # one file per character
    bpy.ops.wm.open_mainfile(filepath=tmp)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name != n: bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, f"{n}_prep.blend"))
    o = bpy.data.objects[n]
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 512
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    co = [v.co for v in o.data.vertices]
    lo = Vector([min(c[i] for c in co) for i in range(3)]); hi = Vector([max(c[i] for c in co) for i in range(3)])
    cen = (lo + hi) / 2; size = max(hi - lo) * 1.1
    cam.data.type = "ORTHO"; cam.data.ortho_scale = size; cam.data.clip_end = size * 12
    for view, loc, rot in (("front", (cen.x, cen.y - size * 3, cen.z), (math.radians(90), 0, 0)),
                           ("side", (cen.x + size * 3, cen.y, cen.z), (math.radians(90), 0, math.radians(90))),
                           ("top", (cen.x, cen.y, cen.z + size * 3), (0, 0, 0))):
        cam.location = loc; cam.rotation_euler = rot
        sc.render.filepath = os.path.join(out_dir, f"{n}_prep_{view}.png"); bpy.ops.render.render(write_still=True)
os.remove(tmp)
print("INFO" + json.dumps({"scale": round(s, 3), "chars": report}))
