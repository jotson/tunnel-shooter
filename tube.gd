extends Spatial

var RING_COUNT = 100
var RING_WIDTH = 2.0
var RING_RADIUS = 5
var RING_VERTICES = 24

var MAX_SPEED = 100
var CURVYNESS = 3

var SEED = 3

var ring_mesh_data = []
var ring_data = []
var ring = 0

const Ball = preload("res://ball.tscn")
const PlayerBall = preload("res://playerball.tscn")
const HallwayLight = preload("res://light.tscn")
const Gate = preload("res://gate.tscn")
const Block = preload("res://block.tscn")

var lights = []
var MAX_LIGHTS = 6

var starting_velocity = Vector3(0, 0, -MAX_SPEED)
var target_velocity : Vector3
var throttle = 0.25
var angular_offset = PI/2
var angular_offset_v = 0.0
var angular_offset_vmax = 2 * PI
var angular_offset_a = 250
var angular_offset_damp = 0.1

var camera_velocity : SpatialVelocityTracker

var playerball = null
var camera_view = CAM.ZERO
enum CAM { ZERO, ONE, TWO }

var rand_color : Color = Color(1,0,0)

var noisex
var noisey
var noisez

var pixels = false

onready var ui = $ui/container


func _ready():
	seed(SEED)
	
	OS.vsync_enabled = true
	
	ui.get_node("VideoPanel/VideoPlayer1").stop()
	ui.get_node("VideoPanel/VideoPlayer2").stop()
	
	ring_mesh_data.resize(Mesh.ARRAY_MAX)
	target_velocity = starting_velocity
	
	camera_velocity = SpatialVelocityTracker.new()
	
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
	
	ui.get_node("View").text = "CAM 0"
	

func _physics_process(delta):
	seed(SEED+ring)
	
	var feet_per_meter = 3.28084
	var feet_per_mile = 5280
	var seconds_per_hour = 3600
	var speed = target_velocity.length() * throttle
	var mph = round(speed * feet_per_meter / feet_per_mile * seconds_per_hour)
	ui.get_node("Speed").text = "[ %d MPH ]-::-[ %d m/s ]" % [mph, round(speed)]
	ui.get_node("FPS").text = "[ %d FPS %s%s]" % [
		Engine.get_frames_per_second(),
		'VSYNC ' if OS.vsync_enabled else '',
		'HD ' if get_viewport().msaa != Viewport.MSAA_DISABLED else 'PIXEL '
		]

	var last_origin = Vector3.ZERO
# warning-ignore:unused_variable
	var last_forward = Vector3.FORWARD
# warning-ignore:unused_variable
	var last_side = Vector3.RIGHT
	if ring_data.size():	
		var last_ring = ring_data[ring_data.size()-1]
		last_origin = last_ring.origin
		last_forward = last_ring.forward
		last_side = last_ring.side
	
	if Input.is_action_just_pressed("vsync"):
		if OS.vsync_enabled:
			OS.vsync_enabled = false
		else:
			OS.vsync_enabled = true
	
	if Input.is_action_just_pressed("debug"):
		if Game.DEBUG:
			Game.DEBUG = false
		else:
			Game.DEBUG = true
			
	if Input.is_action_just_pressed("screen1"):
		OS.window_fullscreen = false
		yield(get_tree(), 'idle_frame')
		OS.current_screen = 0
		yield(get_tree(), 'idle_frame')
		OS.window_fullscreen = true
			
	if Input.is_action_just_pressed("screen2"):
		OS.window_fullscreen = false
		yield(get_tree(), 'idle_frame')
		OS.current_screen = 1
		yield(get_tree(), 'idle_frame')
		OS.window_fullscreen = true

	$TunnelCollision/CollisionShape.visible = Game.DEBUG
	$Camera/Sweep/collision.visible = Game.DEBUG
	
	var input = false
	if $Path.curve.get_point_count() >= RING_COUNT:
		if Input.is_action_pressed("faster"):
			throttle += 0.5 * delta * Input.get_action_strength("faster")
			if throttle >= 1:
				throttle = 1

		if Input.is_action_pressed("slower"):
			throttle -= 0.5 * delta * Input.get_action_strength("slower")
			if throttle <= 0:
				throttle = 0

		if Input.is_action_pressed("left"):
			input = true
			angular_offset_v = lerp(angular_offset_v, angular_offset_a * delta * Input.get_action_strength("left"), angular_offset_damp)
		elif Input.is_action_pressed("right"):
			input = true
			angular_offset_v = lerp(angular_offset_v, -angular_offset_a * delta * Input.get_action_strength("right"), angular_offset_damp)

	# Damp velocity when no input	
	if not input:
		angular_offset_v = lerp(angular_offset_v, 0, angular_offset_damp)
		
	# Clamp max speed
	if abs(angular_offset_v) > angular_offset_vmax:
		angular_offset_v = angular_offset_vmax * angular_offset_v/abs(angular_offset_v)
		
	# Move the player
	angular_offset += angular_offset_v * delta
		
	# Lerp back to bottom
#	if angular_offset < -PI + PI/2:
#		angular_offset = PI + PI/2
#	elif angular_offset > PI + PI/2:
#		angular_offset = -PI + PI/2
#	if not input:
#		angular_offset = lerp(angular_offset, PI/2, 0.03)
		
	if Input.is_action_just_pressed("video"):
		$ui/videoswitchtimer.stop()
		if ui.get_node("VideoPanel").visible:
			ui.get_node("VideoPanel").hide()
			ui.get_node("VideoPanel/VideoPlayer1").stop()
			ui.get_node("VideoPanel/VideoPlayer2").stop()
		else:
			$ui/videoswitchtimer.start()
			ui.get_node("VideoPanel/VideoPlayer2").show()
			ui.get_node("VideoPanel").show()
			ui.get_node("VideoPanel/VideoPlayer1").play()
			ui.get_node("VideoPanel/VideoPlayer2").play()
	
	if Input.is_action_just_pressed("screen"):
		toggle_pixels()

	if Input.is_action_pressed("addball"):
		var this_ring = ring_data[0]
		var o = Ball.instance()
		o.translation = this_ring.origin + this_ring.forward * 4 + this_ring.side.rotated(this_ring.forward, OS.get_ticks_msec()/250.0) * (RING_RADIUS-1)
		add_child(o)
		o.apply_central_impulse(this_ring.forward * target_velocity.length() * throttle * 2)

	if Input.is_action_just_pressed("camera"):
		if camera_view == CAM.ZERO:
			ui.get_node("View").text = "CAM 1"
			camera_view = CAM.ONE
		else:
			ui.get_node("View").text = "CAM 0"
			camera_view = CAM.ZERO
			
		if camera_view == CAM.ZERO:
			$Camera.current = true
			$BallCamera.current = false
		else:
			$Camera.current = false
			$BallCamera.current = true
	
	var dist = last_origin.distance_to($target.translation)
	var t = 1.0 - dist / RING_WIDTH
	
	if playerball == null:
		playerball = PlayerBall.instance()
		playerball.translation = Vector3.DOWN * (RING_RADIUS - 1) + Vector3.FORWARD * 15.0
		add_child(playerball)
		
	if $Path.curve.get_point_count() > 20:
		var points = $Path.curve.get_point_count()
		var world_look = lerp($Path.curve.get_point_position(points-20), $Path.curve.get_point_position(points-19), t)
		var current_pos = ui.get_node("ViewportContainer/Viewport/WorldCam").translation
		ui.get_node("ViewportContainer/Viewport/WorldCam").translation = lerp(current_pos, $target.translation + Vector3(10,10,-50), 0.5)
		ui.get_node("ViewportContainer/Viewport/WorldCam").look_at(world_look, Vector3.UP)

	if $Path.curve.get_point_count() < RING_COUNT:
		t = 0
		camera_velocity.update_position($Camera.translation)
		$BallCamera.look_at(playerball.translation + Vector3.FORWARD, Vector3.UP)
		$BallCamera.translation = lerp($BallCamera.translation, playerball.translation, 0.9)
	else:
		# Nove player ball
		var this_ring = ring_data[6]
		var next_ring = ring_data[7]
		var p = lerp($Path.curve.get_point_position(6), $Path.curve.get_point_position(7), t)
		var side = lerp(this_ring.side, next_ring.side, t)
		var forward = lerp(this_ring.forward, next_ring.forward, t)
		playerball.translation = p + side.rotated(forward, angular_offset) * (RING_RADIUS - 1)
		playerball.look_at(playerball.translation + forward, Vector3.UP)
		
		# NOTE Curve3D.interpolatef() does cubic interpolation (ease out)
		p = lerp($Path.curve.get_point_position(0), $Path.curve.get_point_position(1), t)
		$Camera.translation = p
		p = lerp($Path.curve.get_point_position(6), $Path.curve.get_point_position(7), t)
		$Camera.look_at(p, Vector3.UP)
		camera_velocity.update_position($Camera.translation)

		# Move 1st person camera
		p = lerp($Path.curve.get_point_position(RING_COUNT/4 - 2), $Path.curve.get_point_position(RING_COUNT/4 - 1), t)
		if camera_view == CAM.ZERO:
			$BallCamera.look_at(p, Vector3.UP)
		if camera_view == CAM.ONE:
			$BallCamera.translation = lerp($BallCamera.translation, playerball.translation, 0.9)
			$BallCamera.look_at(p, -side.rotated(forward.normalized(), angular_offset))

	if throttle > 0:
		var scale = 1.0
		scale = 1.0 + throttle * CURVYNESS
		if ring < 20:
			scale = 0.0
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

	var last_origin = null
	var last_forward = null
	var last_side = null
	if ring_data.size():	
		var last_ring = ring_data[ring_data.size()-1]
		last_origin = last_ring.origin
		last_forward = last_ring.forward
		last_side = last_ring.side

	var origin = $target.translation
	if last_origin == null:
		last_origin = origin
	
	var forward : Vector3 = target_velocity.normalized()
	if last_forward == null:
		last_forward = forward
		
	var side : Vector3 = ($target/arm.to_global($target/arm.translation) - $target.translation).normalized()
	if last_side == null:
		last_side = side
		
	if (last_origin - last_forward * RING_WIDTH).distance_to(origin) < RING_WIDTH:
		return
		
	$Path.curve.add_point(origin)
	if $Path.curve.get_point_count() > RING_COUNT:
		$Path.curve.remove_point(0)
		
	if ring % (RING_COUNT / 2) == 0:
		var c1 = rand_range(0,1.0)
		rand_color = Color(c1, rand_range(0,1.0), 1.0-c1)
		
	if ring < RING_COUNT:
		rand_color = Color(0.3, 0.0, 0.04)
	
	if ring % (RING_COUNT / MAX_LIGHTS) == 0:
		if lights.size() < MAX_LIGHTS:
			var l = HallwayLight.instance()
			l.translation = origin# + side.rotated(forward, randf() * 2 * PI) * RING_RADIUS * 0.9
			add_child(l)
			
		if lights.size() > MAX_LIGHTS:
			var l = lights.pop_front()
			l.queue_free()
			
	if randi() % 15 == 0:
		var o = Gate.instance()
		var position = randf() * 2 * PI
		o.translation = origin + side.rotated(forward, position) * RING_RADIUS
		add_child(o)
		o.look_at(o.translation + forward, Vector3.UP)
		o.rotate(forward, position + PI/2)

	if randi() % 20 == 0:
		var o = Block.instance()
		var position = randf() * 2 * PI
		o.translation = origin + side.rotated(forward, position) * RING_RADIUS
		add_child(o)
		o.look_at(o.translation + forward, Vector3.UP)
		o.rotate(forward, position + PI/2)
		
	for j in range(RING_VERTICES):
		var v : Vector3
		var c = Color(1000)
		if (ring + j) % 2 == 0:
			c = rand_color

		var r1 : Vector3 = last_side * RING_RADIUS
		var r2 : Vector3 = side * RING_RADIUS + forward * RING_WIDTH
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
		
	ring_mesh_data[Mesh.ARRAY_VERTEX] = verts
	ring_mesh_data[Mesh.ARRAY_NORMAL] = normals
	ring_mesh_data[Mesh.ARRAY_COLOR] = colors
	
	var aMesh : ArrayMesh = $MeshInstance.mesh
	var count = aMesh.get_surface_count()
	if count > RING_COUNT:
		aMesh.surface_remove(0)
		ring_data.pop_front()
	aMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ring_mesh_data)
	$TunnelCollision/CollisionShape.shape = aMesh.create_trimesh_shape()

	ring_data.append({
		"origin": origin + forward * RING_WIDTH,
		"forward": forward,
		"side": side
	})


func _on_VideoPlayer1_finished():
	ui.get_node("VideoPanel/VideoPlayer1").play()


func _on_VideoPlayer2_finished():
	ui.get_node("VideoPanel/VideoPlayer2").play()


func toggle_pixels():
	if pixels:
		pixels = false
		var window_size = Vector2(1920,1080)
		var aspect = SceneTree.STRETCH_ASPECT_IGNORE
		var stretch_mode = SceneTree.STRETCH_MODE_DISABLED
		$Camera.environment.ss_reflections_enabled = true
		get_tree().set_screen_stretch(stretch_mode, aspect, window_size)
		get_viewport().msaa = Viewport.MSAA_8X
		ui.get_node("ViewportContainer").rect_size = Vector2(360,300)
		ui.get_node("ViewportContainer").margin_left = -360
		ui.get_node("ViewportContainer").margin_bottom = 300
		ui.get_node("ViewportContainer").margin_right = 0
		ui.get_node("ViewportContainer").margin_top = 0
		
		ui.get_node("Speed").rect_scale = Vector2(1,1)
		ui.get_node("Speed").margin_left = 24
		ui.get_node("Speed").margin_top = 8
		
		ui.get_node("View").rect_scale = Vector2(1,1)
		ui.get_node("View").margin_left = 24
		ui.get_node("View").margin_top = 72
		
		ui.get_node("FPS").rect_scale = Vector2(1,1)
		ui.get_node("FPS").margin_right = -24
		ui.get_node("FPS").margin_bottom = -8
		
		ui.get_node("Gamepad").rect_scale = Vector2(1,1)
		ui.get_node("Gamepad").margin_left = 24
		ui.get_node("Gamepad").margin_top = -206
	else:
		pixels = true
		var window_size = Vector2(640,360)
		var aspect = SceneTree.STRETCH_ASPECT_KEEP
		var stretch_mode = SceneTree.STRETCH_MODE_VIEWPORT
		$Camera.environment.ss_reflections_enabled = false
		get_tree().set_screen_stretch(stretch_mode, aspect, window_size)
		get_viewport().msaa = Viewport.MSAA_DISABLED
		
		ui.get_node("ViewportContainer").rect_size = Vector2(120,100)
		ui.get_node("ViewportContainer").margin_left = -120
		ui.get_node("ViewportContainer").margin_bottom = 100
		ui.get_node("ViewportContainer").margin_right = 0
		ui.get_node("ViewportContainer").margin_top = 0
		
		ui.get_node("Speed").rect_scale = Vector2(0.33, 0.33)
		ui.get_node("Speed").margin_left = 8
		ui.get_node("Speed").margin_top = 3
		
		ui.get_node("View").rect_scale = Vector2(0.33, 0.33)
		ui.get_node("View").margin_left = 8
		ui.get_node("View").margin_top = 24
		
		ui.get_node("FPS").rect_scale = Vector2(0.33, 0.33)
		ui.get_node("FPS").margin_right = -8
		ui.get_node("FPS").margin_bottom = -3
		
		ui.get_node("Gamepad").rect_scale = Vector2(0.33, 0.33)
		ui.get_node("Gamepad").margin_left = 8
		ui.get_node("Gamepad").margin_top = -68


func _on_videoswitchtimer_timeout():
	if ui.get_node("VideoPanel/VideoPlayer2").visible:
		ui.get_node("VideoPanel/VideoPlayer2").hide()
	else:
		ui.get_node("VideoPanel/VideoPlayer2").show()


func _on_sweep_body_entered(body):
	if body.is_in_group("object"):
		body.queue_free()


func _on_sweep_area_entered(area):
	if area.is_in_group("object"):
		area.queue_free()
