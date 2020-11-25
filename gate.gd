extends StaticBody

func _ready():
	pass


func _physics_process(_delta):
	$CollisionShape.visible = get_tree().current_scene.debug
	$Area2D/CollisionShape.visible = get_tree().current_scene.debug


func _on_Area2D_body_entered(body):
	queue_free()
