extends Control

## Puzzle selection menu. Lists all puzzles from PuzzleCatalog as a
## responsive grid of cards and starts the selected puzzle in puzzle mode.

const COLOR_BG = Color(0.1, 0.1, 0.13, 1)
const COLOR_TEXT = Color(0.92, 0.94, 0.96)
const COLOR_TEXT_DIM = Color(0.5, 0.52, 0.56)
const COLOR_ACCENT = Color(0.2, 0.5, 0.8)
const COLOR_PANEL = Color(0.12, 0.13, 0.16, 0.9)
const COLOR_PANEL_HOVER = Color(0.16, 0.19, 0.24, 0.95)
const COLOR_STAR = Color(1.0, 0.8, 0.3)
const COLOR_STAR_EMPTY = Color(0.3, 0.32, 0.36)

const DIFFICULTY_MAX = 3

# Card sizing — kept compact so two columns fit at 1280×720.
const CARD_MIN_WIDTH = 360
const CARD_MIN_HEIGHT = 110
const GRID_H_SEPARATION = 18
const GRID_V_SEPARATION = 14

# Width breakpoint at which we switch from 1 column to 2 columns.
const TWO_COLUMN_BREAKPOINT = 900

var _grid: GridContainer


func _ready():
	RenderingServer.set_default_clear_color(COLOR_BG)
	_build_ui()
	get_tree().root.size_changed.connect(_update_columns)


func _build_ui():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var empty_sb = StyleBoxEmpty.new()
	scroll.add_theme_stylebox_override("panel", empty_sb)
	add_child(scroll)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	scroll.add_child(margin)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	center.add_child(main_vbox)

	# --- Title ---
	var title = Label.new()
	title.text = "Puzzles"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Get X in a row within the move budget. Every puzzle takes more than one move."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.x = 2 * CARD_MIN_WIDTH + GRID_H_SEPARATION
	main_vbox.add_child(subtitle)

	_add_spacer(main_vbox, 4)

	# --- Puzzle grid ---
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	_grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	_grid.columns = _desired_columns()
	main_vbox.add_child(_grid)

	var catalog = load("res://Scripts/PuzzleCatalog.gd")
	var puzzles = catalog.get_puzzles()
	for puzzle in puzzles:
		_grid.add_child(_make_puzzle_card(puzzle))

	_add_spacer(main_vbox, 8)

	# --- Back button ---
	var back_center = CenterContainer.new()
	main_vbox.add_child(back_center)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", 16)
	_style_secondary_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	back_center.add_child(back_btn)


func _desired_columns() -> int:
	var w = get_viewport_rect().size.x
	return 2 if w >= TWO_COLUMN_BREAKPOINT else 1


func _update_columns():
	if _grid == null:
		return
	_grid.columns = _desired_columns()


func _make_puzzle_card(puzzle: Dictionary) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
	btn.toggle_mode = false
	btn.focus_mode = Control.FOCUS_ALL
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_entry_button(btn)
	btn.pressed.connect(_on_puzzle_selected.bind(puzzle))

	# Content overlay — sits on top of the button so the whole card is clickable.
	var content = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_right = -18
	content.offset_top = 14
	content.offset_bottom = -14
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(content)

	# Header row: id + name on the left, difficulty stars on the right.
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)

	var name_label = Label.new()
	name_label.text = "%d. %s" % [puzzle.get("id", 0), puzzle.get("name", "Puzzle")]
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(name_label)

	var stars_label = Label.new()
	stars_label.text = _difficulty_stars(puzzle.get("difficulty", 1))
	stars_label.add_theme_font_size_override("font_size", 16)
	stars_label.add_theme_color_override("font_color", COLOR_STAR)
	stars_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(stars_label)

	# Description.
	var desc_label = Label.new()
	desc_label.text = puzzle.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.custom_minimum_size.y = 32
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(desc_label)

	# Footer row: move budget + bomb count summary.
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(footer)

	footer.add_child(_make_meta_label("%d moves" % puzzle.get("max_moves", 1)))
	footer.add_child(_make_meta_label(_bomb_summary(puzzle.get("bombs", []))))
	footer.add_child(_make_meta_label("%d×%d" % [puzzle.get("width", 0), puzzle.get("height", 0)]))

	return btn


func _make_meta_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _bomb_summary(bombs: Array) -> String:
	if bombs.is_empty():
		return "no bombs"
	var counts = {0: 0, 1: 0, 2: 0}
	for b in bombs:
		counts[b] = counts.get(b, 0) + 1
	var labels = ["row", "col", "diag"]
	var parts: Array = []
	for i in range(3):
		if counts[i] > 0:
			parts.append("%d %s" % [counts[i], labels[i]])
	return ", ".join(parts)


func _difficulty_stars(level: int) -> String:
	var filled = clampi(level, 0, DIFFICULTY_MAX)
	var s = ""
	for i in range(DIFFICULTY_MAX):
		s += "★" if i < filled else "☆"
	return s


func _add_spacer(parent: Control, h: float):
	var s = Control.new()
	s.custom_minimum_size.y = h
	parent.add_child(s)


# ============================================================
#  STYLING
# ============================================================

func _style_entry_button(btn: Button):
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14

		match state_name:
			"normal":
				sb.bg_color = COLOR_PANEL
			"hover":
				sb.bg_color = COLOR_PANEL_HOVER
				sb.border_color = COLOR_ACCENT
				sb.border_width_left = 2
				sb.border_width_right = 2
				sb.border_width_top = 2
				sb.border_width_bottom = 2
			"pressed":
				sb.bg_color = COLOR_PANEL.darkened(0.1)
			"focus":
				sb.bg_color = COLOR_PANEL_HOVER
				sb.border_color = COLOR_ACCENT
				sb.border_width_left = 2
				sb.border_width_right = 2
				sb.border_width_top = 2
				sb.border_width_bottom = 2

		btn.add_theme_stylebox_override(state_name, sb)


func _style_secondary_button(btn: Button):
	for state_name in ["normal", "hover", "pressed"]:
		var sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10

		match state_name:
			"normal": sb.bg_color = Color(0.18, 0.2, 0.24)
			"hover":  sb.bg_color = Color(0.25, 0.28, 0.33)
			"pressed": sb.bg_color = Color(0.14, 0.16, 0.19)

		btn.add_theme_stylebox_override(state_name, sb)

	btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT)


# ============================================================
#  ACTIONS
# ============================================================

func _on_puzzle_selected(puzzle: Dictionary):
	GameSettings.play_mode = GameSettings.PlayMode.PUZZLE
	GameSettings.current_puzzle_id = puzzle.get("id", 1)
	get_tree().change_scene_to_file("res://Scenes/GameBoard.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
