extends RigidBody

func _ready():
	pass

func _physics_process(_delta):
	$CollisionShape.visible = Game.DEBUG


func _on_VisibilityNotifier_screen_exited():
	queue_free()
