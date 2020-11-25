extends TextureRect

export var DEVICE = 0
export var DEADZONE = 0.2

var ANALOG_MOVE = 8
var ls_pos : Vector2
var rs_pos : Vector2

func _ready():
	ls_pos = $LS.rect_position
	rs_pos = $RS.rect_position


func _process(_delta):
	if Input.is_joy_button_pressed(DEVICE, 0):
		$A.pressed = true
	else:
		$A.pressed = false

	if Input.is_joy_button_pressed(DEVICE, 1):
		$B.pressed = true
	else:
		$B.pressed = false

	if Input.is_joy_button_pressed(DEVICE, 2):
		$X.pressed = true
	else:
		$X.pressed = false

	if Input.is_joy_button_pressed(DEVICE, 3):
		$Y.pressed = true
	else:
		$Y.pressed = false

	if Input.is_joy_button_pressed(DEVICE, 4):
		$LB.show()
	else:
		$LB.hide()

	if Input.is_joy_button_pressed(DEVICE, 5):
		$RB.show()
	else:
		$RB.hide()

	if Input.is_joy_button_pressed(DEVICE, 6):
		$LT.show()
	else:
		$LT.hide()

	if Input.is_joy_button_pressed(DEVICE, 7):
		$RT.show()
	else:
		$RT.hide()

	if Input.is_joy_button_pressed(DEVICE, 10):
		$Select.pressed = true
	else:
		$Select.pressed = false

	if Input.is_joy_button_pressed(DEVICE, 11):
		$Start.pressed = true
	else:
		$Start.pressed = false

	if Input.is_joy_button_pressed(DEVICE, 12):
		$Dpad/Up.show()
	else:
		$Dpad/Up.hide()

	if Input.is_joy_button_pressed(DEVICE, 13):
		$Dpad/Down.show()
	else:
		$Dpad/Down.hide()

	if Input.is_joy_button_pressed(DEVICE, 14):
		$Dpad/Left.show()
	else:
		$Dpad/Left.hide()

	if Input.is_joy_button_pressed(DEVICE, 15):
		$Dpad/Right.show()
	else:
		$Dpad/Right.hide()
		
	# 0,1 left stick
	# 2,3 right stick
	var v = Vector2(Input.get_joy_axis(DEVICE, 0), Input.get_joy_axis(DEVICE, 1))
	if v.length() > DEADZONE:
		$LS.pressed = true
		$LS.rect_position = ls_pos + v * ANALOG_MOVE
	else:
		$LS.pressed = false
		$LS.rect_position = ls_pos

	v = Vector2(Input.get_joy_axis(DEVICE, 2), Input.get_joy_axis(DEVICE, 3))
	if v.length() > DEADZONE:
		$RS.pressed = true
		$RS.rect_position = rs_pos + v * ANALOG_MOVE
	else:
		$RS.pressed = false
		$RS.rect_position = rs_pos
