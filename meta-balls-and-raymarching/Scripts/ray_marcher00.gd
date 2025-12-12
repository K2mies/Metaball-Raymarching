extends MeshInstance3D

#Define the variable to hold the WorldEnvironment node reference
var world_environment: WorldEnvironment = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1. Find the WorldEnvironment node via Group
	var env_nodes = get_tree().get_nodes_in_group("Environment")
	if env_nodes.size() > 0:
		world_environment = env_nodes[0] as WorldEnvironment
		return
	else:
		print("Error: No node found in 'Environment' group")
	
	# 2. Proceed with passing the texture once the node is found
	if world_environment and world_environment.environment:
		var environment_texture: Texture = get_environment_texture()
		
		if environment_texture:
			#Get the material for surface 0 and set the parameter
			var material: ShaderMaterial = self.get_active_material(0)
			if material:
				material.set_shader_parameter("environment_cubemap", environment_texture)
				print("Environment texture successfully passed to shader uniform")
			else:
				print("Error: No ShaderMaterial fgound on raymarching node")
		else:
			print("Error: Could not retrieve valid environment textre from the WorldEnvironment")

	pass
#Helper function to extract the panorama texture resource
func get_environment_texture() -> Texture:
	if world_environment and world_environment.environment:
		var env_resource: Environment = world_environment.environment
		#Check if the sky setup is correct (assuming Godot 4 and PanoramaSkyMaterial )
		if env_resource.sky and env_resource.sky.sky_material is PanoramaSkyMaterial:
			#Return the origonal imported texture resource (e.g the .hrd file)
			return env_resource.sky.sky_material.panorama
	#return null if any step fails
	return null
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
