# Render: weight segmentation (rest) + key frames of each action. usage: -- name out_png_dir
import bpy, sys, os, math, colorsys, random
name, outd = sys.argv[sys.argv.index("--") + 1:]
sc = bpy.context.scene
ob = bpy.data.objects[f"{name}_mesh"]; arm = bpy.data.objects[f"{name}_rig"]
me = ob.data
# dominant-bone colour attribute
random.seed(3)
cols = {vg.index: colorsys.hsv_to_rgb(random.random(), 0.75, 1) for vg in ob.vertex_groups}
attr = me.color_attributes.new("seg", "FLOAT_COLOR", "POINT")
for v in me.vertices:
    g = max(v.groups, key=lambda g: g.weight)
    attr.data[v.index].color = (*cols[g.group], 1)
bpy.ops.mesh.primitive_plane_add(size=0.02, location=(0, 0, 0))  # floor reference
fl = bpy.context.object; fl.scale = (100, 100, 1)
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"
sc.render.resolution_x = sc.render.resolution_y = 384
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.6; cam.data.clip_end = 50

def shot(path, view):
    if view == "front": cam.location = (0, -5, 0.45); cam.rotation_euler = (math.radians(90), 0, 0)
    else: cam.location = (5, 0, 0.45); cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

arm.animation_data.action = None
for t in arm.animation_data.nla_tracks: t.mute = True
sc.display.shading.color_type = "VERTEX"
arm.data.pose_position = "REST"
sc.frame_set(0); shot(os.path.join(outd, f"{name}_seg_front.png"), "front"); shot(os.path.join(outd, f"{name}_seg_side.png"), "side")
arm.data.pose_position = "POSE"
sc.display.shading.color_type = "TEXTURE" if ob.data.uv_layers else "MATERIAL"
frames = {"walk-loop": [0, 8], "attack": [9, 14], "hurt": [3], "die": [32], "idle-loop": [30]}
for act, fs in frames.items():
    arm.animation_data.action = bpy.data.actions[act]
    if hasattr(arm.animation_data, "action_slot") and bpy.data.actions[act].slots:
        arm.animation_data.action_slot = bpy.data.actions[act].slots[0]
    for f in fs:
        sc.frame_set(f)
        shot(os.path.join(outd, f"{name}_{act}_{f}_side.png"), "side")
        shot(os.path.join(outd, f"{name}_{act}_{f}_front.png"), "front")
