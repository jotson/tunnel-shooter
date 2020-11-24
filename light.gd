extends Spatial

var angle = 0.0


func _ready():
	pass # Replace with function body.


func _process(_delta):
	$OmniLight.light_energy = rand_range(0.5, 1.0)
