extends Control

## Main menu with game and graphics options.

# --- Style constants ---
const COLOR_BG = Color(0.1, 0.1, 0.13, 1)
const COLOR_TEXT = Color(0.92, 0.94, 0.96)
const COLOR_TEXT_DIM = Color(0.5, 0.52, 0.56)
const COLOR_ACCENT = Color(0.2, 0.5, 0.8)
const COLOR_PANEL = Color(0.12, 0.13, 0.16, 0.9)

# --- Game option data ---
var game_modes = ["Local", "vs CPU"]
var difficulties = ["Easy", "Medium", "Hard"]
var board_sizes = [5, 7, 9]
var bomb_counts = [3, 5, 7, 10]
var win_lengths = [3, 4, 5]

# --- Selected game indices ---
var selected_mode = 0
var selected_difficulty = 1
var selected_board_size = 1
var selected_bomb_count = 1
var selected_win_length = 0

# --- Selected graphics indices ---
var selected_fullscreen = 0  # 0=Off, 1=On
var selected_vsync = 1       # 0=Off, 1=On
var selected_window_size = 1 # index into GameSettings.WINDOW_SIZE_LABELS

# --- Button group references ---
var mode_buttons: Array = []
var difficulty_buttons: Array = []
var board_size_buttons: Array = []
var bomb_count_buttons: Array = []
var win_length_buttons: Array = []
var fullscreen_buttons: Array = []
var vsync_buttons: Array = []
var window_size_buttons: Array = []

# --- Dynamic rows ---
var difficulty_row: HBoxContainer
var window_size_row: HBoxContainer


func _ready():
	RenderingServer.set_default_clear_color(COLOR_BG)

	# Read current graphics state from GameSettings
	selected_fullscreen = 1 if GameSettings.fullscreen else 0
	selected_vsync = 1 if GameSettings.vsync else 0
	selected_window_size = GameSettings.window_size_index

	_build_ui()


func _build_ui():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ScrollContainer so menu works on smaller windows
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var empty_sb = StyleBoxEmpty.new()
	scroll.add_theme_stylebox_override("panel", empty_sb)
	add_child(scroll)

	# Margin to create centered feel
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	scroll.add_child(margin)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	center.add_child(main_vbox)

	# ---- Title ----
	var title = Label.new()
	title.text = "Tic Tac Boom"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = '"oh my god they have a bomb" edition'
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	_add_spacer(main_vbox, 16)

	# ---- Game Options Panel ----
	var game_panel = _make_panel()
	main_vbox.add_child(game_panel)

	var game_vbox = game_panel.get_child(0)

	var game_header = Label.new()
	game_header.text = "GAME"
	game_header.add_theme_font_size_override("font_size", 13)
	game_header.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	game_vbox.add_child(game_header)

	mode_buttons = _build_option_row(game_vbox, "Mode",
		game_modes, selected_mode, _on_mode_selected)

	difficulty_buttons = _build_option_row(game_vbox, "Difficulty",
		difficulties, selected_difficulty, _on_difficulty_selected)
	difficulty_row = game_vbox.get_child(game_vbox.get_child_count() - 1)
	difficulty_row.visible = (selected_mode == 1)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.2, 0.22, 0.26))
	game_vbox.add_child(sep)

	board_size_buttons = _build_option_row(game_vbox, "Board Size",
		board_sizes.map(func(s): return "%sx%s" % [s, s]),
		selected_board_size, _on_board_size_selected)

	bomb_count_buttons = _build_option_row(game_vbox, "Bombs",
		bomb_counts.map(func(n): return str(n)),
		selected_bomb_count, _on_bomb_count_selected)

	win_length_buttons = _build_option_row(game_vbox, "Win Length",
		win_lengths.map(func(n): return "%s in a row" % n),
		selected_win_length, _on_win_length_selected)

	# ---- Graphics Panel ----
	var gfx_panel = _make_panel()
	main_vbox.add_child(gfx_panel)

	var gfx_vbox = gfx_panel.get_child(0)

	var gfx_header = Label.new()
	gfx_header.text = "GRAPHICS"
	gfx_header.add_theme_font_size_override("font_size", 13)
	gfx_header.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	gfx_vbox.add_child(gfx_header)

	fullscreen_buttons = _build_option_row(gfx_vbox, "Fullscreen",
		["Off", "On"], selected_fullscreen, _on_fullscreen_selected)

	window_size_buttons = _build_option_row(gfx_vbox, "Window Size",
		Array(GameSettings.WINDOW_SIZE_LABELS),
		selected_window_size, _on_window_size_selected)
	window_size_row = gfx_vbox.get_child(gfx_vbox.get_child_count() - 1)
	window_size_row.visible = (selected_fullscreen == 0)

	vsync_buttons = _build_option_row(gfx_vbox, "VSync",
		["Off", "On"], selected_vsync, _on_vsync_selected)

	# ---- Play Button ----
	_add_spacer(main_vbox, 8)

	var btn_center = CenterContainer.new()
	main_vbox.add_child(btn_center)

	var play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.add_theme_font_size_override("font_size", 24)
	_style_play_button(play_btn)
	play_btn.pressed.connect(_on_play_pressed)
	btn_center.add_child(play_btn)
	play_btn.grab_focus()


# ============================================================
#  HELPERS
# ============================================================

func _add_spacer(parent: Control, height: float):
	var s = Control.new()
	s.custom_minimum_size.y = height
	parent.add_child(s)


func _make_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	return panel


# ============================================================
#  OPTION ROW BUILDER
# ============================================================

func _build_option_row(parent: Control, label_text: String, options: Array, default_idx: int, callback: Callable) -> Array:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.custom_minimum_size.x = 120
	row.add_child(label)

	var btn_group: Array = []

	for i in range(options.size()):
		var btn = Button.new()
		btn.text = options[i]
		btn.add_theme_font_size_override("font_size", 15)
		btn.toggle_mode = true
		btn.button_pressed = (i == default_idx)
		btn.pressed.connect(callback.bind(i))
		_style_option_button(btn, i == default_idx)
		row.add_child(btn)
		btn_group.append(btn)

	return btn_group


func _update_option_group(buttons: Array, selected_idx: int):
	for i in range(buttons.size()):
		buttons[i].button_pressed = (i == selected_idx)
		_style_option_button(buttons[i], i == selected_idx)


# ============================================================
#  GAME CALLBACKS
# ============================================================

func _on_mode_selected(idx: int):
	selected_mode = idx
	_update_option_group(mode_buttons, idx)
	difficulty_row.visible = (idx == 1)


func _on_difficulty_selected(idx: int):
	selected_difficulty = idx
	_update_option_group(difficulty_buttons, idx)


func _on_board_size_selected(idx: int):
	selected_board_size = idx
	_update_option_group(board_size_buttons, idx)


func _on_bomb_count_selected(idx: int):
	selected_bomb_count = idx
	_update_option_group(bomb_count_buttons, idx)


func _on_win_length_selected(idx: int):
	selected_win_length = idx
	_update_option_group(win_length_buttons, idx)


# ============================================================
#  GRAPHICS CALLBACKS — apply immediately
# ============================================================

func _on_fullscreen_selected(idx: int):
	selected_fullscreen = idx
	_update_option_group(fullscreen_buttons, idx)
	window_size_row.visible = (idx == 0)
	GameSettings.fullscreen = (idx == 1)
	GameSettings.apply_graphics()
	GameSettings.save_settings()


func _on_window_size_selected(idx: int):
	selected_window_size = idx
	_update_option_group(window_size_buttons, idx)
	GameSettings.window_size_index = idx
	GameSettings.apply_graphics()
	GameSettings.save_settings()


func _on_vsync_selected(idx: int):
	selected_vsync = idx
	_update_option_group(vsync_buttons, idx)
	GameSettings.vsync = (idx == 1)
	GameSettings.apply_graphics()
	GameSettings.save_settings()


# ============================================================
#  PLAY
# ============================================================

func _on_play_pressed():
	GameSettings.play_mode = selected_mode
	GameSettings.cpu_difficulty = selected_difficulty
	GameSettings.board_size = board_sizes[selected_board_size]
	GameSettings.num_bombs = bomb_counts[selected_bomb_count]
	GameSettings.win_length = win_lengths[selected_win_length]
	get_tree().change_scene_to_file("res://Scenes/GameBoard.tscn")


# ============================================================
#  STYLING
# ============================================================

func _style_play_button(btn: Button):
	for state_name in ["normal", "hover", "pressed"]:
		var sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 48
		sb.content_margin_right = 48
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14

		match state_name:
			"normal": sb.bg_color = COLOR_ACCENT
			"hover": sb.bg_color = COLOR_ACCENT.lightened(0.12)
			"pressed": sb.bg_color = COLOR_ACCENT.darkened(0.1)

		btn.add_theme_stylebox_override(state_name, sb)

	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT)


func _style_option_button(btn: Button, is_selected: bool):
	for state_name in ["normal", "hover", "pressed"]:
		var sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8

		if is_selected:
			match state_name:
				"normal": sb.bg_color = COLOR_ACCENT
				"hover": sb.bg_color = COLOR_ACCENT.lightened(0.1)
				"pressed": sb.bg_color = COLOR_ACCENT.darkened(0.1)
		else:
			match state_name:
				"normal": sb.bg_color = Color(0.18, 0.2, 0.24)
				"hover": sb.bg_color = Color(0.24, 0.26, 0.3)
				"pressed": sb.bg_color = Color(0.15, 0.17, 0.2)

		btn.add_theme_stylebox_override(state_name, sb)

	var text_color = COLOR_TEXT if is_selected else COLOR_TEXT_DIM
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT)
