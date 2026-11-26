extends Node3D

@export var mountain_count := 14
@export var ring_min := 90.0
@export var ring_max := 150.0
@export var cloud_count := 25
@export var cloud_drift_speed := 0.01  # radians per second

var cloud_root: Node3D


func _ready() -> void:
	_build_sky()
	_build_mountains()
	_build_clouds()


func _process(delta: float) -> void:
	cloud_root.rotate_y(cloud_drift_speed * delta)


func _build_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.15, 0.4, 0.85)
	sky_mat.sky_horizon_color = Color(0.75, 0.88, 1.0)
	sky_mat.ground_horizon_color = Color(0.75, 0.88, 1.0)
	sky_mat.ground_bottom_color = Color(0.85, 0.92, 1.0)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.9, 1.0)
	env.fog_density = 0.004  # fades far mountains into haze

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # same mountains every run

	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.45, 0.52, 0.65)
	rock.roughness = 1.0

	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.95, 0.97, 1.0)
	snow.roughness = 1.0

	for i in mountain_count:
		var angle := (TAU / mountain_count) * i + rng.randf_range(-0.15, 0.15)
		var dist := rng.randf_range(ring_min, ring_max)
		var height := rng.randf_range(50.0, 100.0)
		var base_radius := rng.randf_range(22.0, 38.0)
		var base_y := -25.0  # base hidden below the clouds

		var m := Node3D.new()
		m.position = Vector3(cos(angle) * dist, base_y, sin(angle) * dist)
		add_child(m)

		# Rocky body
		var body := CylinderMesh.new()
		body.top_radius = 0.0
		body.bottom_radius = base_radius
		body.height = height
		body.radial_segments = 7  # low-poly, chunky look
		body.material = rock
		var body_mi := MeshInstance3D.new()
		body_mi.mesh = body
		body_mi.position.y = height * 0.5
		m.add_child(body_mi)

		# Snow cap: the top 35% of the same cone shape
		var cap_h := height * 0.35
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = base_radius * 0.35 * 1.02
		cap.height = cap_h
		cap.radial_segments = 7
		cap.material = snow
		var cap_mi := MeshInstance3D.new()
		cap_mi.mesh = cap
		cap_mi.position.y = height - cap_h * 0.5
		m.add_child(cap_mi)


func _build_clouds() -> void:
	cloud_root = Node3D.new()
	add_child(cloud_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color.WHITE
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.material = cloud_mat

	for i in cloud_count:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(25.0, 120.0)
		var cloud := Node3D.new()
		cloud.position = Vector3(
			cos(angle) * dist,
			rng.randf_range(-30.0, -12.0),  # below the platform
			sin(angle) * dist
		)
		cloud_root.add_child(cloud)

		# 3-5 overlapping flattened spheres per cloud
		for j in rng.randi_range(3, 5):
			var mi := MeshInstance3D.new()
			mi.mesh = puff
			var s := rng.randf_range(4.0, 9.0)
			mi.scale = Vector3(s * 1.6, s * 0.6, s)
			mi.position = Vector3(rng.randf_range(-8, 8), rng.randf_range(-1, 1), rng.randf_range(-5, 5))
			cloud.add_child(mi)
