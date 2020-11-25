extends Area

func _ready():
	pass


func _physics_process(_delta):
	$CollisionShape.visible = Game.DEBUG
	
	if translation.distance_to(Game.PLAYER_POSITION) > 500:
		queue_free()


func _on_Area_body_entered(body):
	if visible:
		# TODO play sound
		pass
	hide()
