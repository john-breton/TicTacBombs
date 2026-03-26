extends TextureRect

signal tile_clicked
signal tile_hovered(pos: Vector2i)
signal tile_unhovered(pos: Vector2i)

var is_empty = true
var grid_position = Vector2i(0, 0)

@onready var mark_sprite = $MarkSprite
@onready var animation_player = $AnimationPlayer

# --- Hover / Preview ---
var _hover_overlay: ColorRect
var _is_hovered = false
var _is_bomb_preview = false
var _is_win_highlighted = false

const COLOR_HOVER_NORMAL = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_HOVER_INVALID = Color(1.0, 0.2, 0.2, 0.06)
const COLOR_BOMB_PREVIEW = Color(1.0, 0.3, 0.1, 0.25)
const COLOR_WIN_GLOW = Color(1.0, 0.9, 0.3, 0.35)


func _ready():
	# Create hover/preview overlay programmatically
	_hover_overlay = ColorRect.new()
	_hover_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_overlay.color = Color(0, 0, 0, 0)
	add_child(_hover_overlay)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


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
	_clear_all_highlights()


## Restore a vanished tile to a fresh, clickable, empty state.
func revive():
	animation_player.stop()
	self_modulate = Color(1, 1, 1, 1)
	modulate = Color(1, 1, 1, 1)
	mark_sprite.modulate = Color(1, 1, 1, 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var explosion_rect = get_node_or_null("ExplosionRect")
	if explosion_rect:
		explosion_rect.modulate = Color(1, 1, 1, 0)
		explosion_rect.scale = Vector2(0.1, 0.1)
	var found_effect = get_node_or_null("FoundEffect")
	if found_effect:
		found_effect.modulate = Color(1, 1, 1, 0)
	is_empty = true
	_clear_all_highlights()


# ============================================================
#  HOVER
# ============================================================

func _on_mouse_entered():
	_is_hovered = true
	tile_hovered.emit(grid_position)
	if not _is_bomb_preview and not _is_win_highlighted:
		_hover_overlay.color = COLOR_HOVER_NORMAL


func _on_mouse_exited():
	_is_hovered = false
	tile_unhovered.emit(grid_position)
	if not _is_bomb_preview and not _is_win_highlighted:
		_hover_overlay.color = Color(0, 0, 0, 0)


# ============================================================
#  BOMB PREVIEW
# ============================================================

func show_bomb_preview():
	_is_bomb_preview = true
	_hover_overlay.color = COLOR_BOMB_PREVIEW


func hide_bomb_preview():
	_is_bomb_preview = false
	if _is_hovered:
		_hover_overlay.color = COLOR_HOVER_NORMAL
	else:
		_hover_overlay.color = Color(0, 0, 0, 0)


# ============================================================
#  WIN LINE HIGHLIGHT
# ============================================================

func show_win_highlight():
	_is_win_highlighted = true
	_hover_overlay.color = COLOR_WIN_GLOW
	# Pulsing tween
	var tween = create_tween().set_loops()
	tween.tween_property(_hover_overlay, "color:a", 0.15, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_hover_overlay, "color:a", 0.4, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ============================================================
#  INTERNAL
# ============================================================

func _clear_all_highlights():
	_is_bomb_preview = false
	_is_win_highlighted = false
	_is_hovered = false
	if _hover_overlay:
		_hover_overlay.color = Color(0, 0, 0, 0)
