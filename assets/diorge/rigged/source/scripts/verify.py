import bpy, sys, os, json
d = sys.argv[sys.argv.index("--") + 1]
res = {}
def moving(a):  # number of animation channels whose value actually changes
    fcs = [fc for l in a.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves] if hasattr(a, "layers") and a.layers else list(a.fcurves)
    return sum(1 for fc in fcs if len({round(k.co[1], 4) for k in fc.keyframe_points}) > 1)
for f in sorted(os.listdir(d)):
    if not f.endswith(".glb"): continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(d, f))
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    res[f] = {"bones": len(arms[0].data.bones) if arms else 0,
              "tris": sum(len(m.data.polygons) for m in meshes),
              "height": round(max(max((m.matrix_world @ v.co).z for v in m.data.vertices) for m in meshes), 3),
              "anims": {a.name: [list(a.frame_range), moving(a)] for a in bpy.data.actions},
              "size_kb": os.path.getsize(os.path.join(d, f)) // 1024}
print("VERIFY" + json.dumps(res))
