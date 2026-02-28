extends TextureRect

signal tile_clicked

var is_empty = true
var grid_position = Vector2i(0, 0)

@onready var mark_sprite = $MarkSprite
@onready var animation_player = $AnimationPlayer


func _gui_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.is_pressed():
		tile_clicked.emit(grid_position)


func set_mark(texture):
	mark_sprite.texture = texture
	is_empty = false


func play_found_effect():
	animation_player.play("found_bomb")


func clear_mark():
	mark_sprite.texture = null
	is_empty = true


func vanish():
	animation_player.play("explode")
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_empty = false


## Restore a vanished tile to a fresh, clickable, empty state.
func revive():
	animation_player.stop()
	# Reset all properties that vanish/explode animation touches
	self_modulate = Color(1, 1, 1, 1)
	modulate = Color(1, 1, 1, 1)
	mark_sprite.modulate = Color(1, 1, 1, 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Reset explosion & found-bomb overlay rects
	var explosion_rect = get_node_or_null("ExplosionRect")
	if explosion_rect:
		explosion_rect.modulate = Color(1, 1, 1, 0)
		explosion_rect.scale = Vector2(0.1, 0.1)
	var found_effect = get_node_or_null("FoundEffect")
	if found_effect:
		found_effect.modulate = Color(1, 1, 1, 0)
	is_empty = true
