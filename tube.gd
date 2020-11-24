extends Spatial

var RING_COUNT = 100
var RING_WIDTH = 2.0
var RING_RADIUS = 5
var RING_VERTICES = 24

var MAX_SPEED = 100
var CURVYNESS = 3

var SEED = 2

var rings = []
var ring = 0

const Ball = preload("res://ball.tscn")
const HallwayLight = preload("res://light.tscn")

var lights = []
var MAX_LIGHTS = 6

var starting_velocity = Vector3(0, 0, -MAX_SPEED)
var target_velocity : Vector3
var throttle = 0.25
var camera_velocity : SpatialVelocityTracker

var last_origin : Vector3
var last_forward : Vector3
var last_tangent : Vector3

var ball : RigidBody = null

var rand_color : Color = Color(1,0,0)

var noisex
var noisey
var noisez

var pixels = false


func _ready():
	OS.vsync_enabled = false
	
	$ui/VideoPanel/VideoPlayer1.stop()
	$ui/VideoPanel/VideoPlayer2.stop()
	
	rings.resize(Mesh.ARRAY_MAX)
	target_velocity = starting_velocity
	
	camera_velocity = SpatialVelocityTracker.new()
	
	seed(SEED)
	
	noisex = OpenSimplexNoise.new()
	noisex.seed = randi()
	noisex.octaves = 3
	noisex.period = 20.0
	noisex.persistence = 0.8
	
	noisey = OpenSimplexNoise.new()
	noisey.seed = randi()
	noisey.octaves = 3
	noisey.period = 20.0
	noisey.persistence = 0.8

	noisez = OpenSimplexNoise.new()
	noisez.seed = randi()
	noisez.octaves = 3
	noisez.period = 20.0
	noisez.persistence = 0.8
	

func _physics_process(delta):
	var feet_per_meter = 3.28084
	var feet_per_mile = 5280
	var seconds_per_hour = 3600
	var speed = target_velocity.length() * throttle
	var mph = round(speed * feet_per_meter / feet_per_mile * seconds_per_hour)
	$ui/Speed.text = "[ %d MPH ]-::-[ %d m/s ]" % [mph, round(speed)]
	$ui/FPS.text = "[ %d FPS %s]" % [Engine.get_frames_per_second(), 'VSYNC ' if OS.vsync_enabled else '' ]
	
	if Input.is_action_just_pressed("vsync"):
		if OS.vsync_enabled:
			OS.vsync_enabled = false
		else:
			OS.vsync_enabled = true
	
	if Input.is_action_pressed("faster"):
		throttle += 0.5 * delta
		if throttle >= 1:
			throttle = 1

	if Input.is_action_pressed("slower"):
		throttle -= 0.5 * delta
		if throttle <= 0:
			throttle = 0
	
	if Input.is_action_just_pressed("video"):
		if $ui/VideoPanel.visible:
			$ui/VideoPanel.hide()
			$ui/VideoPanel/VideoPlayer1.stop()
			$ui/VideoPanel/VideoPlayer2.stop()
		else:
			$ui/VideoPanel.show()
			$ui/VideoPanel/VideoPlayer1.play()
			$ui/VideoPanel/VideoPlayer2.play()
	
	if Input.is_action_just_pressed("screen"):
		toggle_pixels()
	
	if ball and Input.is_action_just_pressed("camera"):
		if $Camera.current:
			$Camera.current = false
			$BallCamera.current = true
		else:
			$Camera.current = true
			$BallCamera.current = false
	
	if throttle > 0:
		var dist = last_origin.distance_to($target.translation)
		var t = 1.0 - dist / RING_WIDTH

		var world_look = lerp($Path.curve.get_point_position(RING_COUNT*0.8-1), $Path.curve.get_point_position(RING_COUNT*0.8), t)
		if $Path.curve.get_point_count() < RING_COUNT*0.8:
			world_look = $target.translation
		$ui/ViewportContainer/Viewport/WorldCam.translation = $target.translation + Vector3(60, 60, 60)
		$ui/ViewportContainer/Viewport/WorldCam.look_at(world_look, Vector3.UP)

		if $Path.curve.get_point_count() < RING_COUNT:
			t = 0
			camera_velocity.update_position($Camera.translation)
		else:
			if ball == null:
				ball = Ball.instance()
				ball.translation = Vector3(0,0,-15)
				add_child(ball)
			else:
				if $Camera.translation.distance_to(ball.translation) < 20 and ball.linear_velocity.length() < camera_velocity.get_tracked_linear_velocity().length():
					ball.apply_central_impulse(camera_velocity.get_tracked_linear_velocity().normalized() * 1)
				var p = lerp($Path.curve.get_point_position(RING_COUNT/4 - 2), $Path.curve.get_point_position(RING_COUNT/4 - 1), t)
				$BallCamera.translation = lerp($BallCamera.translation, ball.translation, 0.7)
				$BallCamera.look_at(p, Vector3.UP)
					
			# NOTE Curve3D.interpolatef() does cubic interpolation (ease out)
			var p = lerp($Path.curve.get_point_position(0), $Path.curve.get_point_position(1), t)
			$Camera.translation = p
			p = lerp($Path.curve.get_point_position(RING_COUNT/4 - 2), $Path.curve.get_point_position(RING_COUNT/4 - 1), t)
			$Camera.look_at(p, Vector3.UP)
			camera_velocity.update_position($Camera.translation)
			
		var scale = 1.0
		scale = 1.0 + throttle * CURVYNESS
		target_velocity.x += noisex.get_noise_1d(ring * 0.3) * scale
		target_velocity.y += noisey.get_noise_1d(ring * 0.3) * scale
		target_velocity.z += noisez.get_noise_1d(ring * 0.3) * scale
		target_velocity = target_velocity.normalized() * MAX_SPEED
		
		$target.look_at($target.translation + target_velocity, Vector3.UP)
		$target.global_translate(target_velocity * delta * throttle)

	create_ring()
	

func create_ring():
	var verts = PoolVector3Array()
	var normals = PoolVector3Array()
	var colors = PoolColorArray()

	var origin = $target.translation
	if last_origin == null:
		last_origin = origin
	
	if (last_origin - last_forward * RING_WIDTH).distance_to(origin) < RING_WIDTH:
		return
		
	var forward : Vector3 = target_velocity.normalized()
	if last_forward == null:
		last_forward = forward
		
	var tangent : Vector3 = ($target/arm.to_global($target/arm.translation) - $target.translation).normalized()
	if last_tangent == null:
		last_tangent = tangent
		
	$Path.curve.add_point(origin)
	if $Path.curve.get_point_count() > RING_COUNT:
		$Path.curve.remove_point(0)
		
	if ring % (RING_COUNT / 2) == 0:
		var c1 = rand_range(0,1.0)
		rand_color = Color(c1, rand_range(0,1.0), 1.0-c1)
	
	if ring % (RING_COUNT / MAX_LIGHTS) == 0:
		if lights.size() < MAX_LIGHTS:
			var l = HallwayLight.instance()
			l.translation = origin# + tangent.rotated(forward, randf() * 2 * PI) * RING_RADIUS * 0.9
			add_child(l)
			
		if lights.size() > MAX_LIGHTS:
			var l = lights.pop_front()
			l.queue_free()
		
	for j in range(RING_VERTICES):
		var v : Vector3
		var c = Color(1000)
		if (ring + j) % 2 == 0:
			c = rand_color

		var r1 : Vector3 = last_tangent * RING_RADIUS
		var r2 : Vector3 = tangent * RING_RADIUS + forward * RING_WIDTH
		var this_vert = float(j)/float(RING_VERTICES) * 2 * PI
		var next_vert = float(j+1)/float(RING_VERTICES) * 2 * PI
		
		# Triangle 1
		v = last_origin + r1.rotated(last_forward, this_vert)
		verts.append(v)
		normals.append(v.normalized())
		colors.append(c)
		v = origin + r2.rotated(forward, next_vert)
		verts.append(v)
		normals.append(v.normalized())
		colors.append(c)
		v = origin + r2.rotated(forward, this_vert)
		verts.append(v)
		normals.append(v.normalized())
		colors.append(c)

		# Triangle 2
		v = last_origin + r1.rotated(last_forward, this_vert)
		verts.append(v)
		normals.append(v.normalized())
		colors.append(c)
		v = last_origin + r1.rotated(last_forward, next_vert)
		verts.append(v)
		normals.append(v.normalized())
		colors.append(c)
		v = origin + r2.rotated(forward, next_vert)
		verts.append(v)
		normals.append(v.normalized())
		colors.append(c)

	ring += 1
		
	rings[Mesh.ARRAY_VERTEX] = verts
	rings[Mesh.ARRAY_NORMAL] = normals
	rings[Mesh.ARRAY_COLOR] = colors
	
	var aMesh : ArrayMesh = $MeshInstance.mesh
	var count = aMesh.get_surface_count()
	if count > RING_COUNT:
		aMesh.surface_remove(0)
	aMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rings)
	$StaticBody/CollisionShape.shape = aMesh.create_trimesh_shape()

	last_origin = origin + forward * RING_WIDTH
	last_forward = forward
	last_tangent = tangent
	


func _on_VideoPlayer1_finished():
	$ui/VideoPanel/VideoPlayer1.play()


func _on_VideoPlayer2_finished():
	$ui/VideoPanel/VideoPlayer2.play()


func toggle_pixels():
	if pixels:
		pixels = false
		var window_size = Vector2(1920,1080)
		var aspect = SceneTree.STRETCH_ASPECT_IGNORE
		var stretch_mode = SceneTree.STRETCH_MODE_DISABLED
		get_tree().set_screen_stretch(stretch_mode, aspect, window_size)
		get_viewport().msaa = Viewport.MSAA_8X
		$ui/ViewportContainer.rect_size = Vector2(360,360)
		$ui/ViewportContainer.rect_position = Vector2(1920-360-10, 10)
		$ui/Speed.rect_scale = Vector2(1,1)
		$ui/FPS.rect_scale = Vector2(1,1)
	else:
		pixels = true
		var window_size = Vector2(640,360)
		var aspect = SceneTree.STRETCH_ASPECT_KEEP
		var stretch_mode = SceneTree.STRETCH_MODE_VIEWPORT
		get_tree().set_screen_stretch(stretch_mode, aspect, window_size)
		get_viewport().msaa = Viewport.MSAA_DISABLED
		$ui/ViewportContainer.rect_size = Vector2(120,120)
		$ui/ViewportContainer.rect_position = Vector2(640-120-10, 10)
		$ui/Speed.rect_scale = Vector2(0.33, 0.33)
		$ui/FPS.rect_scale = Vector2(0.33, 0.33)


func _on_videoswitchtimer_timeout():
	if $ui/VideoPanel/VideoPlayer2.visible:
		$ui/VideoPanel/VideoPlayer2.hide()
	else:
		$ui/VideoPanel/VideoPlayer2.show()
