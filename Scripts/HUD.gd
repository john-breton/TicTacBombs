extends CanvasLayer

## HUD overlay for TicTacBombs — dark themed, prominent layout.

# --- Signals to GameBoard ---
signal bomb_selected(bomb_type: int)
signal bomb_cancelled
signal restart_requested
signal menu_requested

# --- Textures (assigned via setup()) ---
var x_texture: Texture2D
var o_texture: Texture2D

# --- Loaded Scripts ---
var _bomb_icon_script: GDScript

# --- UI Node References ---
var turn_icon: TextureRect
var turn_label: Label
var x_side: VBoxContainer
var o_side: VBoxContainer
var x_bomb_container: HBoxContainer
var o_bomb_container: HBoxContainer
var x_label: Label
var o_label: Label
var armed_banner: PanelContainer
var armed_label: Label
var cancel_btn: Button
var overlay: ColorRect
var result_label: Label
var cpu_thinking_label: Label

# --- CPU mode ---
var _cpu_mode = false

# --- Constants ---
const BOMB_NAMES = ["Row", "Column", "Diagonal"]
const BOMB_COLORS = [
	Color(0.4, 0.75, 1.0),   # Row — cyan-blue
	Color(0.45, 1.0, 0.5),   # Column — green
	Color(1.0, 0.55, 0.25),  # Diagonal — orange
]

const COLOR_BG_PANEL = Color(0.12, 0.13, 0.16, 0.9)
const COLOR_BG_DARK = Color(0.08, 0.09, 0.11, 0.95)
const COLOR_ACCENT_X = Color(0.4, 0.7, 1.0)
const COLOR_ACCENT_O = Color(1.0, 0.47, 0.35)
const COLOR_ARMED = Color(0.9, 0.3, 0.2, 0.9)
const COLOR_TEXT = Color(0.88, 0.9, 0.92)
const COLOR_TEXT_DIM = Color(0.5, 0.52, 0.56)


func setup(x_tex: Texture2D, o_tex: Texture2D):
	x_texture = x_tex
	o_texture = o_tex


func _ready():
	_bomb_icon_script = load("res://Scripts/BombIcon.gd")
	_build_ui()


# ============================================================
#  STYLE HELPERS
# ============================================================

func _make_panel_stylebox(bg_color: Color, corner_radius: int = 8, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border_color != Color.TRANSPARENT:
		sb.border_color = border_color
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
	return sb


func _make_button_stylebox(bg_color: Color, corner_radius: int = 6) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _style_button(btn: Button, bg_color: Color, hover_color: Color = Color(), text_color: Color = COLOR_TEXT):
	if hover_color == Color():
		hover_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("normal", _make_button_stylebox(bg_color))
	btn.add_theme_stylebox_override("hover", _make_button_stylebox(hover_color))
	btn.add_theme_stylebox_override("pressed", _make_button_stylebox(bg_color.darkened(0.1)))
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color.darkened(0.2))


# ============================================================
#  UI CONSTRUCTION
# ============================================================

func _build_ui():
	var root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_theme_constant_override("separation", 6)
	root.add_child(main_vbox)

	# Top section: margin + turn indicator + armed banner
	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_margin)

	var top_vbox = VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 8)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top_vbox)

	_build_turn_indicator(top_vbox)
	_build_armed_banner(top_vbox)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(spacer)

	# Bottom section: margin + inventory
	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 20)
	bottom_margin.add_theme_constant_override("margin_right", 20)
	bottom_margin.add_theme_constant_override("margin_bottom", 12)
	bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(bottom_margin)

	_build_inventory_bar(bottom_margin)

	# Game-over overlay
	_build_game_over_overlay(root)


func _build_turn_indicator(parent: Control):
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_stylebox(COLOR_BG_PANEL, 10))
	parent.add_child(panel)

	var center = CenterContainer.new()
	panel.add_child(center)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	center.add_child(hbox)

	turn_icon = TextureRect.new()
	turn_icon.custom_minimum_size = Vector2(36, 36)
	turn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	turn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hbox.add_child(turn_icon)

	turn_label = Label.new()
	turn_label.text = "'s Turn"
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", COLOR_TEXT)
	hbox.add_child(turn_label)

	cpu_thinking_label = Label.new()
	cpu_thinking_label.text = "  thinking..."
	cpu_thinking_label.add_theme_font_size_override("font_size", 16)
	cpu_thinking_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	cpu_thinking_label.visible = false
	hbox.add_child(cpu_thinking_label)


func _build_armed_banner(parent: Control):
	armed_banner = PanelContainer.new()
	armed_banner.add_theme_stylebox_override("panel", _make_panel_stylebox(COLOR_ARMED, 8))
	armed_banner.visible = false
	parent.add_child(armed_banner)

	var center = CenterContainer.new()
	armed_banner.add_child(center)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	center.add_child(hbox)

	armed_label = Label.new()
	armed_label.text = "Bomb Armed"
	armed_label.add_theme_font_size_override("font_size", 18)
	armed_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(armed_label)

	cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	_style_button(cancel_btn, Color(0.3, 0.3, 0.35), Color(0.4, 0.4, 0.45))
	cancel_btn.pressed.connect(_on_cancel_pressed)
	hbox.add_child(cancel_btn)


func _build_inventory_bar(parent: Control):
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)

	# --- Player X panel (left) ---
	var x_panel = PanelContainer.new()
	x_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_panel.add_theme_stylebox_override("panel", _make_panel_stylebox(COLOR_BG_PANEL, 10, COLOR_ACCENT_X.darkened(0.3), 2))
	bar.add_child(x_panel)

	x_side = VBoxContainer.new()
	x_side.add_theme_constant_override("separation", 8)
	x_panel.add_child(x_side)

	x_label = Label.new()
	x_label.text = "PLAYER X"
	x_label.add_theme_font_size_override("font_size", 16)
	x_label.add_theme_color_override("font_color", COLOR_ACCENT_X)
	x_side.add_child(x_label)

	x_bomb_container = HBoxContainer.new()
	x_bomb_container.add_theme_constant_override("separation", 8)
	x_bomb_container.custom_minimum_size.y = 48
	x_side.add_child(x_bomb_container)

	var x_empty_hint = Label.new()
	x_empty_hint.name = "EmptyHint"
	x_empty_hint.text = "No bombs"
	x_empty_hint.add_theme_font_size_override("font_size", 13)
	x_empty_hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	x_bomb_container.add_child(x_empty_hint)

	# --- Player O panel (right) ---
	var o_panel = PanelContainer.new()
	o_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o_panel.add_theme_stylebox_override("panel", _make_panel_stylebox(COLOR_BG_PANEL, 10, COLOR_ACCENT_O.darkened(0.3), 2))
	bar.add_child(o_panel)

	o_side = VBoxContainer.new()
	o_side.add_theme_constant_override("separation", 8)
	o_panel.add_child(o_side)

	o_label = Label.new()
	o_label.text = "PLAYER O"
	o_label.add_theme_font_size_override("font_size", 16)
	o_label.add_theme_color_override("font_color", COLOR_ACCENT_O)
	o_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	o_side.add_child(o_label)

	o_bomb_container = HBoxContainer.new()
	o_bomb_container.add_theme_constant_override("separation", 8)
	o_bomb_container.custom_minimum_size.y = 48
	o_bomb_container.alignment = BoxContainer.ALIGNMENT_END
	o_side.add_child(o_bomb_container)

	var o_empty_hint = Label.new()
	o_empty_hint.name = "EmptyHint"
	o_empty_hint.text = "No bombs"
	o_empty_hint.add_theme_font_size_override("font_size", 13)
	o_empty_hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	o_bomb_container.add_child(o_empty_hint)


func _build_game_over_overlay(parent: Control):
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.05, 0.08, 0.8)
	overlay.visible = false
	parent.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_stylebox(COLOR_BG_DARK, 16, Color(0.3, 0.35, 0.4), 2))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 36)
	result_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(result_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var play_btn = Button.new()
	play_btn.text = "Play Again"
	play_btn.add_theme_font_size_override("font_size", 18)
	_style_button(play_btn, Color(0.2, 0.5, 0.8))
	play_btn.pressed.connect(func(): restart_requested.emit())
	btn_hbox.add_child(play_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.add_theme_font_size_override("font_size", 18)
	_style_button(menu_btn, Color(0.25, 0.27, 0.3))
	menu_btn.pressed.connect(func(): menu_requested.emit())
	btn_hbox.add_child(menu_btn)


# ============================================================
#  PUBLIC API
# ============================================================

func update_turn(player: int):
	var is_x = (player == 1)
	turn_icon.texture = x_texture if is_x else o_texture

	# Dim inactive side
	x_side.modulate.a = 1.0 if is_x else 0.35
	o_side.modulate.a = 0.35 if is_x else 1.0

	_set_bombs_clickable(x_bomb_container, is_x)
	# In CPU mode, O's bombs are never clickable by human
	_set_bombs_clickable(o_bomb_container, (not is_x) and (not _cpu_mode))


func add_bomb(player: int, bomb_type: int):
	var container = x_bomb_container if player == 1 else o_bomb_container

	# Remove "No bombs" hint if present
	var hint = container.get_node_or_null("EmptyHint")
	if hint:
		hint.queue_free()

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	btn.tooltip_text = BOMB_NAMES[bomb_type] + " Bomb"
	_style_button(btn, Color(0.18, 0.2, 0.25), Color(0.25, 0.28, 0.33))
	btn.pressed.connect(_on_bomb_icon_pressed.bind(bomb_type, btn))

	var icon = Control.new()
	icon.set_script(_bomb_icon_script)
	icon.bomb_type = bomb_type
	icon.icon_color = BOMB_COLORS[bomb_type]
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	btn.add_child(icon)

	container.add_child(btn)


func show_armed(bomb_type: int):
	armed_label.text = "%s Bomb — Click a tile to detonate" % BOMB_NAMES[bomb_type]
	armed_banner.visible = true


func hide_armed():
	armed_banner.visible = false


func show_winner(player_name: String):
	result_label.text = "%s Wins!" % player_name
	overlay.visible = true


func show_draw():
	result_label.text = "It's a Draw!"
	overlay.visible = true


## Enable CPU mode — changes O's label and disables O's bomb clicks.
func set_cpu_mode(enabled: bool):
	_cpu_mode = enabled
	if enabled:
		o_label.text = "CPU"
		_set_bombs_clickable(o_bomb_container, false)


## Show or hide the "thinking..." indicator next to the turn label.
func show_cpu_thinking(show: bool):
	cpu_thinking_label.visible = show


## Remove a specific bomb icon from a player's inventory (used by CPU).
func remove_bomb(player: int, bomb_type: int):
	var container = o_bomb_container if player == 2 else x_bomb_container

	for child in container.get_children():
		if not (child is BaseButton):
			continue
		# Check if this button has a BombIcon child with matching type
		for sub in child.get_children():
			if sub.has_method("_draw") and "bomb_type" in sub and sub.bomb_type == bomb_type:
				child.queue_free()
				# Re-show hint if it was the last bomb
				await child.tree_exited
				if container.get_child_count() == 0:
					_add_empty_hint(container)
				return


# ============================================================
#  INTERNAL
# ============================================================

func _on_bomb_icon_pressed(bomb_type: int, btn: Button):
	btn.queue_free()

	# Re-show hint if container will be empty (only the freed btn remains)
	var container = btn.get_parent() as HBoxContainer
	if container and container.get_child_count() <= 1:
		_add_empty_hint(container)

	show_armed(bomb_type)
	bomb_selected.emit(bomb_type)


func _on_cancel_pressed():
	hide_armed()
	bomb_cancelled.emit()


func _set_bombs_clickable(container: HBoxContainer, enabled: bool):
	for child in container.get_children():
		if child is BaseButton:
			child.disabled = not enabled


func _add_empty_hint(container: HBoxContainer):
	var hint = Label.new()
	hint.name = "EmptyHint"
	hint.text = "No bombs"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	container.add_child(hint)
