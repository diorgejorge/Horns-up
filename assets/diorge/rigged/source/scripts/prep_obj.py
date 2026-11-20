# Textured OBJ -> <name>_prep.blend (keeps UV + material). Optionally snaps a loose weapon part into the hand.
# usage: blender -b --factory-startup -P prep_obj.py -- <obj> <name> <out_dir>
import bpy, bmesh, sys, os, json, math, statistics
from mathutils import Vector, Matrix

src, name, out_dir = sys.argv[sys.argv.index("--") + 1:]
sys.path.insert(0, os.path.dirname(__file__))
from landmarks import MODELS
cfg = MODELS[name]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src)  # converts OBJ Y-up to Blender Z-up
ob = bpy.context.selected_objects[0]
ob.name = ob.data.name = name
bpy.context.view_layer.objects.active = ob
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
zs = [v.co.z for v in me.vertices]; z0 = min(zs); h = max(zs) - z0  # z0 hoisted: min() per vertex was O(n²)
s = 0.98 / h if abs(h - 0.98) > 0.05 else 1.0
me.transform(Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -z0)))

TARGET_TRIS = 40000
ntris = sum(len(p.vertices) - 2 for p in me.polygons)
if ntris > TARGET_TRIS * 1.25:
    dm = ob.modifiers.new("dec", "DECIMATE"); dm.ratio = TARGET_TRIS / ntris
    bpy.ops.object.modifier_apply(modifier="dec")
    me = ob.data

info = {"name": name, "tris_in": ntris, "verts": len(me.vertices), "faces": len(me.polygons), "uv": len(me.uv_layers),
        "materials": [m.name for m in me.materials], "height": round(h * s, 3)}

snap = cfg.get("snap_weapon")
if snap:
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    # connected islands
    seen, islands = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        st, isl = [v], []; seen.add(v.index)
        while st:
            a = st.pop(); isl.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen: seen.add(b.index); st.append(b)
        islands.append(isl)
    lo, hi = Vector(snap["box_min"]), Vector(snap["box_max"])
    def inside(isl):
        c = sum((v.co for v in isl), Vector()) / len(isl)
        return all(lo[i] <= c[i] <= hi[i] for i in range(3))
    weapon = max((i for i in islands if inside(i)), key=len)
    wset = {v.index for v in weapon}
    body = [v.co for v in bm.verts if v.index not in wset]
    # hand position from the front-render landmarks (same mapping as rig.py), depth from body verts
    mn = Vector([min(c[i] for c in body) for i in range(3)]); mx = Vector([max(c[i] for c in body) for i in range(3)])
    allv = [v.co for v in bm.verts]
    amn = Vector([min(c[i] for c in allv) for i in range(3)]); amx = Vector([max(c[i] for c in allv) for i in range(3)])
    cc = (amn + amx) / 2; K = max(amx - amn) * 1.1 / 512
    hx = cc.x + (snap["hand_px"][0] - 256) * K; hz = cc.z - (snap["hand_px"][1] - 256) * K
    ys = [c.y for c in body if abs(c.x - hx) < 0.03 and abs(c.z - hz) < 0.03]
    hand = Vector((hx, statistics.median(ys), hz))
    # grip = just above the cross-guard (widest slice of the blade along X), sword held point-down
    zs_w = sorted(v.co.z for v in weapon)
    zlo, zhi = zs_w[0], zs_w[-1]
    best_z, best_w = zlo, 0
    for k in range(60):
        z0 = zlo + (zhi - zlo) * k / 60; z1 = z0 + (zhi - zlo) / 60
        xs = [v.co.x for v in weapon if z0 <= v.co.z < z1]
        if xs and max(xs) - min(xs) > best_w: best_w, best_z = max(xs) - min(xs), (z0 + z1) / 2
    wx = statistics.median(v.co.x for v in weapon); wy = statistics.median(v.co.y for v in weapon)
    grip = Vector((wx, wy, best_z + snap["grip_above_guard"]))
    # tilt the blade forward about the grip so the tip clears the floor
    length = grip.z - zlo
    tilt = math.acos(max(-1, min(1, (hand.z - 0.03) / length))) if length > hand.z - 0.03 else 0.0
    R = Matrix.Rotation(-tilt, 4, "X")  # negative X rotation sends a down-pointing tip toward -Y (forward)
    M = Matrix.Translation(hand) @ R @ Matrix.Translation(-grip)
    for v in weapon: v.co = M @ v.co
    bm.to_mesh(me); bm.free()
    info.update({"weapon_verts": len(weapon), "hand": [round(c, 3) for c in hand],
                 "grip": [round(c, 3) for c in grip], "tilt_deg": round(math.degrees(tilt), 1)})
    vg = ob.vertex_groups.new(name="rigid:" + snap["bone"])
    vg.add(list(wset), 1.0, "REPLACE")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, f"{name}_prep.blend"))

# reference renders (same framing as the landmark renders: 512 px, ortho = 1.1 x largest extent)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = sc.render.resolution_y = 512
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
co = [v.co for v in ob.data.vertices]
lo = Vector([min(c[i] for c in co) for i in range(3)]); hi = Vector([max(c[i] for c in co) for i in range(3)])
cen = (lo + hi) / 2; size = max(hi - lo) * 1.1
cam.data.type = "ORTHO"; cam.data.ortho_scale = size; cam.data.clip_end = size * 12
for view, loc, rot in (("front", (cen.x, cen.y - size * 3, cen.z), (math.radians(90), 0, 0)),
                       ("side", (cen.x + size * 3, cen.y, cen.z), (math.radians(90), 0, math.radians(90)))):
    cam.location = loc; cam.rotation_euler = rot
    sc.render.filepath = os.path.join(out_dir, f"{name}_prep_{view}.png")
    bpy.ops.render.render(write_still=True)
print("INFO" + json.dumps(info))
