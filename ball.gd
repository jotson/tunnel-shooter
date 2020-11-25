extends KinematicBody


func _ready():
	pass # Replace with function body.


func _physics_process(_delta):
	$CollisionShape.visible = get_tree().current_scene.debug
