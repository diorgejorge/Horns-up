# Import STL, normalise to ~1 m tall, decimate, report loose parts. Saves <out>/<name>_prep.blend
import bpy, sys, os, json
src, name, out_dir = sys.argv[sys.argv.index("--") + 1:]
TARGET_TRIS = 40000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.stl_import(filepath=src)
ob = bpy.context.selected_objects[0]
ob.name = ob.data.name = name
bpy.context.view_layer.objects.active = ob
h = max((ob.matrix_world @ v.co).z for v in ob.data.vertices)
s = 0.98 / h if h > 5 else 1.0
ob.scale = (s, s, s)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001); bpy.ops.object.mode_set(mode="OBJECT")
m = ob.modifiers.new("dec", "DECIMATE"); m.ratio = TARGET_TRIS / len(ob.data.polygons)
bpy.ops.object.modifier_apply(modifier="dec")
# loose part report (without separating permanently)
import bmesh
bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
seen = set(); parts = []
for v in bm.verts:
    if v.index in seen: continue
    stack = [v]; seen.add(v.index); idx = []
    while stack:
        a = stack.pop(); idx.append(a.index)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b.index not in seen: seen.add(b.index); stack.append(b)
    co = [bm.verts[i].co for i in idx]
    parts.append({"n": len(idx), "min": [round(min(c[k] for c in co), 3) for k in range(3)],
                  "max": [round(max(c[k] for c in co), 3) for k in range(3)]})
parts.sort(key=lambda p: -p["n"])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, f"{name}_prep.blend"))
print("INFO" + json.dumps({"name": name, "tris": len(ob.data.polygons), "nparts": len(parts), "top": parts[:8]}))
