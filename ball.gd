extends RigidBody

func _ready():
	pass

func _physics_process(_delta):
	$CollisionShape.visible = Game.DEBUG
