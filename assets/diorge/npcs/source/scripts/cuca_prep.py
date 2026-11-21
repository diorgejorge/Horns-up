# Prepara o GLB da Cuca vindo do Tripo: aplica a rotação do import, solda e reduz para 40k triângulos.
# usage: blender -b -P cuca_prep.py -- <cuca.glb original> <saida cuca_prep.blend>
import bpy, sys
src, dst = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
ob.name = ob.data.name = "cuca"
bpy.context.view_layer.objects.active = ob; ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)  # o import do glTF deixa 90° em quaternion
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001); bpy.ops.object.mode_set(mode="OBJECT")
m = ob.modifiers.new("dec", "DECIMATE"); m.ratio = 40000 / len(ob.data.polygons)
bpy.ops.object.modifier_apply(modifier="dec")
bpy.ops.wm.save_as_mainfile(filepath=dst)
