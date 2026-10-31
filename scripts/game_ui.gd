extends CanvasLayer
## Responsive, self-contained presentation for the tiny cat adventure.

signal start_requested
signal pause_requested
signal resume_requested
signal respawn_requested
signal wardrobe_requested
signal cat_selected(cat_id: String)
signal outfit_selected(outfit_id: String)
signal purchase_requested(outfit_id: String)
signal sound_toggled(enabled: bool)
signal camera_reset_requested

const INK := Color("47374d")
const MUTED := Color("8a7c88")
const CREAM := Color("fff9ec")
const CORAL := Color("f27792")
const MINT := Color("bfe7d4")
const LILAC := Color("d7c8f4")
const GOLD := Color("ffd36b")
const CATS := [
	{"id": "orange", "name": "橘子", "color": Color("f3ac62"), "detail": Color("dc8651")},
	{"id": "white", "name": "奶糖", "color": Color("fff9ee"), "detail": Color("f1c8c8")},
	{"id": "gray", "name": "芝麻", "color": Color("aaaab7"), "detail": Color("77758c")},
	{"id": "brown", "name": "可可", "color": Color("b88465"), "detail": Color("815747")},
	{"id": "ragdoll", "name": "布丁", "color": Color("f5e7d7"), "detail": Color("8d766a")},
]
const OUTFITS := [
	{"id": "none", "name": "原味猫咪", "description": "毛茸茸，就是最好的装扮。", "price": 0, "color": Color("fff0ce")},
	{"id": "mint_scarf", "name": "薄荷围巾", "description": "把一阵清凉的风，系在脖子上。", "price": 8, "color": MINT},
	{"id": "berry_cap", "name": "莓果贝雷帽", "description": "今天也是一只甜甜的艺术家。", "price": 12, "color": Color("f9c8d6")},
	{"id": "star_cape", "name": "星星披风", "description": "带上小星星，向更高处出发。", "price": 18, "color": LILAC},
	{"id": "crown", "name": "奶油王冠", "description": "每一只勇敢的小猫，都值得加冕。", "price": 25, "color": Color("ffe5a0")},
]

class TinyIcon extends Control:
	var kind: String = "paw"
	var tint: Color = Color("f3ac62")
	var detail: Color = Color("d98b58")
	var ink: Color = Color("47374d")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var scale_value := minf(size.x, size.y) / 80.0
		var origin := size * 0.5
		draw_set_transform(origin, 0.0, Vector2.ONE * scale_value)
		match kind:
			"cat", "orange", "white", "gray", "brown", "ragdoll":
				draw_colored_polygon(PackedVector2Array([Vector2(-29, -7), Vector2(-30, -32), Vector2(-8, -19)]), tint)
				draw_colored_polygon(PackedVector2Array([Vector2(29, -7), Vector2(30, -32), Vector2(8, -19)]), tint)
				draw_colored_polygon(PackedVector2Array([Vector2(-25, -12), Vector2(-25, -25), Vector2(-14, -17)]), Color("efa8a6"))
				draw_colored_polygon(PackedVector2Array([Vector2(25, -12), Vector2(25, -25), Vector2(14, -17)]), Color("efa8a6"))
				draw_circle(Vector2.ZERO, 30.0, tint)
				if kind == "ragdoll":
					draw_circle(Vector2(-17, -8), 12, detail)
					draw_circle(Vector2(17, -8), 12, detail)
				elif kind != "white":
					draw_line(Vector2(-9, -25), Vector2(-6, -16), detail, 4, true)
					draw_line(Vector2(0, -28), Vector2(0, -17), detail, 4, true)
					draw_line(Vector2(9, -25), Vector2(6, -16), detail, 4, true)
				draw_circle(Vector2(-10, 0), 2.8, ink)
				draw_circle(Vector2(10, 0), 2.8, ink)
				draw_circle(Vector2(-19, 8), 4.4, Color(0.96, 0.59, 0.62, 0.38))
				draw_circle(Vector2(19, 8), 4.4, Color(0.96, 0.59, 0.62, 0.38))
				draw_colored_polygon(PackedVector2Array([Vector2(-3, 7), Vector2(3, 7), Vector2(0, 10)]), Color("d98589"))
				draw_line(Vector2(0, 10), Vector2(-4, 13), ink, 1.5, true)
				draw_line(Vector2(0, 10), Vector2(4, 13), ink, 1.5, true)
			"food":
				draw_colored_polygon(PackedVector2Array([Vector2(-27, 1), Vector2(-9, -22), Vector2(25, -6), Vector2(22, 20), Vector2(-7, 25)]), Color("c4884e"))
				draw_colored_polygon(PackedVector2Array([Vector2(-22, -2), Vector2(-7, -20), Vector2(21, -7), Vector2(3, 8)]), Color("e4b778"))
				draw_circle(Vector2(-2, -7), 2.5, Color("f7d99e"))
				draw_circle(Vector2(10, 3), 2.5, Color("9f673f"))
			"mint_scarf":
				draw_style_box(_icon_style(Color("68bb9e"), 9), Rect2(-27, -14, 54, 22))
				draw_colored_polygon(PackedVector2Array([Vector2(2, 1), Vector2(19, 0), Vector2(24, 31), Vector2(9, 29)]), Color("87d3b5"))
				draw_line(Vector2(10, 24), Vector2(21, 24), Color("e5fff0"), 3, true)
			"berry_cap":
				draw_circle(Vector2(1, -4), 27, Color("c95d83"))
				draw_style_box(_icon_style(Color("e27c9c"), 12), Rect2(-32, -19, 64, 33))
				draw_line(Vector2(3, -28), Vector2(6, -35), Color("8d496c"), 5, true)
				draw_style_box(_icon_style(Color("8d496c"), 4), Rect2(-21, 12, 42, 8))
			"star_cape":
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -24), Vector2(12, -24), Vector2(33, 28), Vector2(0, 22), Vector2(-33, 28)]), Color("a291d3"))
				_draw_star(Vector2(0, 2), 13, Color("ffe18f"))
			"crown":
				draw_colored_polygon(PackedVector2Array([Vector2(-29, -19), Vector2(-13, -6), Vector2(0, -28), Vector2(13, -6), Vector2(29, -19), Vector2(23, 24), Vector2(-23, 24)]), Color("edbd50"))
				draw_line(Vector2(-22, 17), Vector2(22, 17), Color("ffe7a6"), 5, true)
				draw_circle(Vector2(0, 5), 5, Color("e58b96"))
			"burger":
				draw_style_box(_icon_style(Color("e8af63"), 20), Rect2(-31, -24, 62, 33))
				draw_style_box(_icon_style(Color("8e6f52"), 5), Rect2(-30, 5, 60, 12))
				draw_line(Vector2(-31, 5), Vector2(31, 5), Color("99c980"), 7, true)
				draw_style_box(_icon_style(Color("f2c77e"), 8), Rect2(-30, 18, 60, 11))
				draw_line(Vector2(-13, -14), Vector2(-10, -16), Color("fff0ca"), 3, true)
				draw_line(Vector2(8, -17), Vector2(11, -15), Color("fff0ca"), 3, true)
			"pause":
				draw_style_box(_icon_style(ink, 3), Rect2(-17, -23, 10, 46))
				draw_style_box(_icon_style(ink, 3), Rect2(7, -23, 10, 46))
			"close":
				draw_line(Vector2(-14, -14), Vector2(14, 14), ink, 5, true)
				draw_line(Vector2(14, -14), Vector2(-14, 14), ink, 5, true)
			_:
				draw_circle(Vector2(-19, -13), 9, tint)
				draw_circle(Vector2(0, -23), 9, tint)
				draw_circle(Vector2(19, -13), 9, tint)
				draw_circle(Vector2(-30, 4), 7, tint)
				draw_colored_polygon(PackedVector2Array([Vector2(-20, 21), Vector2(-19, 9), Vector2(-7, -2), Vector2(7, -2), Vector2(19, 9), Vector2(20, 21), Vector2(11, 28), Vector2(0, 23), Vector2(-11, 28)]), tint)
	func _icon_style(color: Color, radius: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		return style
	func _draw_star(center: Vector2, radius: float, color: Color) -> void:
		var points := PackedVector2Array()
		for index in range(10):
			var angle := -PI * 0.5 + index * PI / 5.0
			var length := radius if index % 2 == 0 else radius * 0.46
			points.append(center + Vector2(cos(angle), sin(angle)) * length)
		draw_colored_polygon(points, color)

var modal_open: bool = false
var home_visible: bool = true
var _root: Control
var _top: MarginContainer
var _brand_sub: Label
var _currency: Label
var _wardrobe_button: Button
var _home: VBoxContainer
var _home_title: Label
var _home_subtitle: Label
var _home_note: Label
var _start_button: Button
var _stage: PanelContainer
var _stage_text: Label
var _stage_detail: Label
var _progress: ProgressBar
var _controls: PanelContainer
var _controls_label: Label
var _modal_scrim: ColorRect
var _modal_center: CenterContainer
var _modal_panel: PanelContainer
var _modal_content: VBoxContainer
var _modal_scroll: ScrollContainer
var _toast: Panel
var _toast_label: Label
var _toast_tween: Tween
var _muted: bool = false
var _modal_kind: String = ""
var _last_state: Dictionary = {}
var _font: Font
var _bold_font: Font

func _ready() -> void:
	layer = 10
	var font_file := load("res://assets/fonts/NotoSansSC.ttf") as FontFile
	# Auto oversampling only sees the viewport stretch, not our portrait UI scale.
	font_file.oversampling = 2.0
	var regular_variation := FontVariation.new()
	regular_variation.base_font = font_file
	regular_variation.variation_opentype = {2003265652: 450.0} # OpenType 'wght' axis.
	_font = regular_variation
	var bold_variation := FontVariation.new()
	bold_variation.base_font = font_file
	bold_variation.variation_opentype = {2003265652: 700.0}
	_bold_font = bold_variation
	_root = Control.new()
	_root.name = "ResponsiveUI"
	_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var ui_theme := Theme.new()
	ui_theme.default_font = _font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	_root.theme = ui_theme
	_build_top()
	_build_home()
	_build_hud()
	_build_modal()
	_build_toast()
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_home()

func _build_top() -> void:
	_top = MarginContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_root.add_child(_top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_top.add_child(row)
	var mark := _icon("paw", Vector2(38, 38), CORAL)
	row.add_child(mark)
	var brand := VBoxContainer.new()
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_theme_constant_override("separation", 0)
	row.add_child(brand)
	brand.add_child(_label("喵跃云端", 19, INK, true))
	_brand_sub = _label("01 / 糖果晴空", 11, MUTED)
	brand.add_child(_brand_sub)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var currency_panel := PanelContainer.new()
	currency_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	currency_panel.add_theme_stylebox_override("panel", _style(Color("fff9ee"), 22, 12, 7, Color("ead8c9")))
	row.add_child(currency_panel)
	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 8)
	currency_panel.add_child(food_row)
	food_row.add_child(_icon("food", Vector2(29, 29)))
	_currency = _label("0", 23, INK, true)
	_currency.custom_minimum_size.x = 34
	food_row.add_child(_currency)
	_wardrobe_button = _button("猫咪衣橱  C", Color("fff9ee"), false)
	_wardrobe_button.custom_minimum_size = Vector2(128, 46)
	_wardrobe_button.pressed.connect(func() -> void: wardrobe_requested.emit())
	row.add_child(_wardrobe_button)
	var pause_button := _button("", Color("fff9ee"), false)
	pause_button.custom_minimum_size = Vector2(46, 46)
	pause_button.tooltip_text = "暂停 / Esc"
	var pause_icon := _icon("pause", Vector2(19, 19))
	pause_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_icon.position -= Vector2(9.5, 9.5)
	pause_button.add_child(pause_icon)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	row.add_child(pause_button)

func _build_home() -> void:
	_home = VBoxContainer.new()
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home.add_theme_constant_override("separation", 14)
	_root.add_child(_home)
	var eyebrow_row := HBoxContainer.new()
	eyebrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home.add_child(eyebrow_row)
	var eyebrow := PanelContainer.new()
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyebrow.add_theme_stylebox_override("panel", _style(Color("ffe6b1"), 12, 12, 6))
	eyebrow.add_child(_label("把世界，跳成游乐场", 12, INK, true))
	eyebrow_row.add_child(eyebrow)
	_home_title = _label("喵跃\n云端", 88, INK, true)
	_home_title.add_theme_constant_override("line_spacing", -12)
	_home_title.add_theme_color_override("font_shadow_color", Color(1, 0.98, 0.93, 0.7))
	_home_title.add_theme_constant_override("shadow_offset_x", 0)
	_home_title.add_theme_constant_override("shadow_offset_y", 3)
	_home.add_child(_home_title)
	var english := _label("P A W S   I N   T H E   C L O U D S", 12, Color("9c6881"), true)
	_home.add_child(english)
	_home_subtitle = _label("小小猫咪，大大的甜蜜冒险。", 18, INK)
	_home.add_child(_home_subtitle)
	_home_note = _label("踩着软糖和扑克牌，一路蹦向天空。\n收集猫粮，给今天的自己换一身可爱。", 13, MUTED)
	_home_note.add_theme_constant_override("line_spacing", 7)
	_home.add_child(_home_note)
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home.add_child(gap)
	var cta_row := HBoxContainer.new()
	cta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_row.add_theme_constant_override("separation", 12)
	_home.add_child(cta_row)
	_start_button = _button("开始冒险    →", CORAL, true)
	_start_button.custom_minimum_size = Vector2(208, 56)
	_start_button.add_theme_font_size_override("font_size", 18)
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	cta_row.add_child(_start_button)
	var small_note := _label("轻轻一跃\n快乐起飞", 12, MUTED)
	small_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	small_note.add_theme_constant_override("line_spacing", 4)
	cta_row.add_child(small_note)

func _build_hud() -> void:
	_stage = PanelContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_theme_stylebox_override("panel", _style(Color(1, 0.976, 0.93, 0.92), 20, 17, 12))
	_root.add_child(_stage)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_stage.add_child(row)
	row.add_child(_icon("burger", Vector2(44, 44)))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_stage_text = _label("向天空出发", 14, INK, true)
	info.add_child(_stage_text)
	_stage_detail = _label("汉堡检查站 · 0     高度 0 m", 10, MUTED)
	info.add_child(_stage_detail)
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.custom_minimum_size = Vector2(168, 4)
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _style(Color("e9e1dd"), 3, 0, 0))
	_progress.add_theme_stylebox_override("fill", _style(CORAL, 3, 0, 0))
	info.add_child(_progress)
	_controls = PanelContainer.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_theme_stylebox_override("panel", _style(Color(1, 0.976, 0.93, 0.88), 18, 16, 9))
	_root.add_child(_controls)
	_controls_label = _label("WASD 移动   空格 跃向下一块   按住空格 连跳   鼠标拖动 视角   滚轮 缩放", 11, Color("756975"))
	_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_child(_controls_label)

func _build_modal() -> void:
	_modal_scrim = ColorRect.new()
	_modal_scrim.name = "ModalInputShield"
	_modal_scrim.color = Color(0.21, 0.15, 0.25, 0.28)
	_modal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_modal_scrim)
	_modal_center = CenterContainer.new()
	_modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_center.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_scrim.add_child(_modal_center)
	_modal_panel = PanelContainer.new()
	_modal_panel.add_theme_stylebox_override("panel", _style(CREAM, 28, 26, 24, Color("e4d6de"), true))
	_modal_center.add_child(_modal_panel)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_panel.add_child(_modal_scroll)
	_modal_content = VBoxContainer.new()
	_modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_content.add_theme_constant_override("separation", 16)
	_modal_scroll.add_child(_modal_content)
	_modal_scrim.hide()

func _build_toast() -> void:
	# A Panel deliberately avoids inheriting an autowrapped Label's transient
	# minimum height before the first container layout pass.
	_toast = Panel.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.clip_contents = true
	_toast.add_theme_stylebox_override("panel", _style(INK, 20, 22, 12))
	_root.add_child(_toast)
	_toast_label = _label("", 15, CREAM, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.max_lines_visible = 3
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_label.clip_text = true
	_toast.add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_label.offset_left = 22
	_toast_label.offset_right = -22
	_toast_label.offset_top = 12
	_toast_label.offset_bottom = -12
	_toast.hide()

func show_home(has_save: bool = false) -> void:
	home_visible = true
	_home.show()
	_stage.hide()
	_start_button.text = "继续冒险    →" if has_save else "开始冒险    →"
	_hide_modal_without_signal()
	_layout()

func show_game() -> void:
	home_visible = false
	_home.hide()
	_stage.show()
	_hide_modal_without_signal()
	_layout()

func update_hud(food: int, current: int, total: int, checkpoint: int, height_value: float) -> void:
	_currency.text = str(food)
	_stage_text.text = "云端旅程  %02d / %02d" % [mini(current, total), total]
	_stage_detail.text = "汉堡检查站 · %d     高度 %.0f m" % [checkpoint, maxf(height_value, 0.0)]
	_progress.max_value = maxi(total, 1)
	_progress.value = current

func show_toast(message: String) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_label.text = message
	_layout()
	_toast.show()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast.hide)

func show_wardrobe(state: Dictionary) -> void:
	var previous_scroll := _modal_scroll.scroll_vertical if _modal_kind == "wardrobe" else 0
	_last_state = state.duplicate(true)
	_open_modal("wardrobe")
	_modal_header("猫咪衣橱", "挑一只喜欢的小猫，把快乐穿在身上。")
	var balance := HBoxContainer.new()
	balance.add_theme_constant_override("separation", 8)
	balance.add_child(_icon("food", Vector2(25, 25)))
	balance.add_child(_label("我的猫粮  %d" % int(state.get("food", 0)), 15, INK, true))
	_modal_content.add_child(balance)
	_modal_content.add_child(_label("01  /  选择你的小猫", 13, MUTED, true))
	var cat_grid := GridContainer.new()
	cat_grid.name = "CatGrid"
	cat_grid.columns = 5
	cat_grid.add_theme_constant_override("h_separation", 9)
	cat_grid.add_theme_constant_override("v_separation", 9)
	_modal_content.add_child(cat_grid)
	for cat_data: Dictionary in CATS:
		var cat_id: String = cat_data["id"]
		var selected: bool = str(state.get("cat_id", "orange")) == cat_id
		var tile := _button("", Color("fff1d6") if selected else Color("f2eee9"), false)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(108, 113)
		if selected:
			tile.add_theme_stylebox_override("normal", _style(Color("fff1d6"), 17, 8, 8, Color("e2ba75")))
		tile.pressed.connect(func() -> void: cat_selected.emit(cat_id))
		cat_grid.add_child(tile)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 8
		content.offset_bottom = -8
		content.add_theme_constant_override("separation", 0)
		tile.add_child(content)
		var face := _icon(cat_id, Vector2(62, 62), cat_data["color"])
		face.detail = cat_data["detail"]
		content.add_child(face)
		var name_label := _label(str(cat_data["name"]), 14, INK, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)
		var status_label := _label("正在冒险" if selected else "免费切换", 10, Color("a88049") if selected else MUTED)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(status_label)
	_modal_content.add_child(_label("02  /  今日穿搭", 13, MUTED, true))
	var outfit_grid := GridContainer.new()
	outfit_grid.name = "OutfitGrid"
	outfit_grid.columns = 5
	outfit_grid.add_theme_constant_override("h_separation", 9)
	outfit_grid.add_theme_constant_override("v_separation", 9)
	_modal_content.add_child(outfit_grid)
	for outfit_data: Dictionary in OUTFITS:
		_add_outfit_tile(outfit_grid, outfit_data, state)
	var hint := _label("猫粮藏在沿途的平台上。每一次小小的勇敢，都有奖励。", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_content.add_child(hint)
	_layout()
	_modal_scroll.set_deferred("scroll_vertical", previous_scroll)

func _add_outfit_tile(grid: GridContainer, data: Dictionary, state: Dictionary) -> void:
	var outfit_id: String = data["id"]
	var owned: bool = outfit_id == "none" or outfit_id in state.get("owned", [])
	var equipped: bool = str(state.get("outfit_id", "none")) == outfit_id
	var prices: Dictionary = state.get("prices", {})
	var price: int = int(prices.get(outfit_id, data["price"]))
	var affordable: bool = int(state.get("food", 0)) >= price
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 108
	panel.add_theme_stylebox_override("panel", _style(Color("f3eee8"), 17, 9, 10, CORAL if equipped else Color.TRANSPARENT))
	grid.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var icon_background := PanelContainer.new()
	icon_background.add_theme_stylebox_override("panel", _style(data["color"], 12, 0, 0))
	content.add_child(icon_background)
	icon_background.add_child(_icon("cat" if outfit_id == "none" else outfit_id, Vector2(68, 70)))
	var name_label := _label(str(data["name"]), 12, INK, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	var caption := _label("基础装扮" if outfit_id == "none" else "%d  猫粮" % price, 11, MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(caption)
	var button_text := "已穿戴" if equipped else ("穿上它" if owned else ("兑换" if affordable else "猫粮不足"))
	var button := _button(button_text, CORAL if equipped else (MINT if owned or affordable else Color("e5dfdc")), false)
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 12)
	button.disabled = equipped or (not owned and not affordable)
	if equipped:
		button.add_theme_color_override("font_disabled_color", INK)
	button.tooltip_text = str(data["description"])
	button.pressed.connect(func() -> void:
		if owned:
			outfit_selected.emit(outfit_id)
		else:
			purchase_requested.emit(outfit_id)
	)
	content.add_child(button)

func show_pause() -> void:
	_open_modal("pause")
	_modal_header("在云朵上歇一会儿", "下一次轻轻起跳，依然有甜蜜在等你。")
	var intro := PanelContainer.new()
	intro.add_theme_stylebox_override("panel", _style(Color("eee7f6"), 18, 18, 15))
	_modal_content.add_child(intro)
	var intro_row := HBoxContainer.new()
	intro_row.add_theme_constant_override("separation", 15)
	intro.add_child(intro_row)
	intro_row.add_child(_icon("burger", Vector2(62, 62)))
	var intro_text := _label("不按方向键时，空格会帮你跃向下一块平台。\n按住空格连续跳跃，WASD 可自由移动和空中调整。\n踩上小物件会弹起，汉堡检查站可以安心休息。\n不小心跌落，会回到最近点亮的汉堡。", 13, INK)
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_text.add_theme_constant_override("line_spacing", 6)
	intro_row.add_child(intro_text)
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 26)
	controls.add_theme_constant_override("v_separation", 12)
	_modal_content.add_child(controls)
	var bindings := [["W A S D / 方向键", "移动 / 空中调整"], ["空格 / 按住空格", "跃向下一块 / 连续跳跃"], ["拖动鼠标", "自由转动视角"], ["鼠标滚轮", "拉近 / 拉远"], ["R", "返回检查站"], ["C / Esc", "猫咪衣橱 / 暂停"]]
	for binding: Array in bindings:
		controls.add_child(_label(str(binding[0]), 13, INK, true))
		controls.add_child(_label(str(binding[1]), 13, MUTED))
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 12)
	_modal_content.add_child(settings)
	var sound := _button("声音：关闭" if _muted else "声音：开启", Color("efe8f6"), false)
	sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound.pressed.connect(func() -> void:
		_muted = not _muted
		sound.text = "声音：关闭" if _muted else "声音：开启"
		sound_toggled.emit(not _muted)
	)
	settings.add_child(sound)
	var camera := _button("重置视角", Color("efe8f6"), false)
	camera.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera.pressed.connect(func() -> void:
		camera_reset_requested.emit()
		show_toast("视角已回到小猫身后")
	)
	settings.add_child(camera)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_modal_content.add_child(actions)
	var resume := _button("继续冒险    →", CORAL, true)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.pressed.connect(_request_resume)
	actions.add_child(resume)
	var reset := _button("返回检查站", Color("f0e8dc"), false)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		_request_resume()
		respawn_requested.emit()
	)
	actions.add_child(reset)
	_layout()

func show_finish(state: Dictionary) -> void:
	_open_modal("finish")
	_modal_header("云端，已被你征服！", "小小的爪子，也能抵达大大的世界。")
	var hero := _icon("crown", Vector2(112, 100))
	_modal_content.add_child(hero)
	var congrats := _label("今天的你，闪闪发光。", 26, INK, true)
	congrats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_content.add_child(congrats)
	var stats := _label("已收集猫粮  %d\n已回到起点，猫粮与装扮都已保留。" % int(state.get("food", 0)), 15, MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_constant_override("line_spacing", 10)
	_modal_content.add_child(stats)
	var explore := _button("从起点再出发", CORAL, true)
	explore.pressed.connect(_request_resume)
	_modal_content.add_child(explore)
	var wardrobe := _button("打开猫咪衣橱", Color("efe7f5"), false)
	wardrobe.pressed.connect(func() -> void: wardrobe_requested.emit())
	_modal_content.add_child(wardrobe)
	_layout()

func hide_modal() -> void:
	_hide_modal_without_signal()

func _request_resume() -> void:
	hide_modal()
	resume_requested.emit()

func set_muted(muted: bool) -> void:
	_muted = muted

func _hide_modal_without_signal() -> void:
	modal_open = false
	_modal_kind = ""
	_modal_scrim.hide()

func _open_modal(kind: String) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.hide()
	modal_open = true
	_modal_kind = kind
	for child: Node in _modal_content.get_children():
		_modal_content.remove_child(child)
		child.queue_free()
	_modal_scroll.scroll_vertical = 0
	_modal_scrim.show()

func _modal_header(title: String, subtitle: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_modal_content.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 6)
	row.add_child(words)
	var heading := _label(title, 27, INK, true)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(heading)
	var detail := _label(subtitle, 13, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(detail)
	var close := _button("", Color("eee7e2"), false)
	close.custom_minimum_size = Vector2(36, 36)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "关闭 / Esc"
	close.pressed.connect(_request_resume)
	row.add_child(close)
	var close_icon := _icon("close", Vector2(19, 19))
	close_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	close_icon.position -= Vector2(9.5, 9.5)
	close.add_child(close_icon)

func _layout() -> void:
	if not is_instance_valid(_root):
		return
	var visible_size := get_viewport().get_visible_rect().size
	var portrait_window := visible_size.x < visible_size.y * 0.95
	var ui_scale := 1.0
	if portrait_window:
		var readable_width := clampf(float(get_window().size.x), 420.0, 760.0)
		ui_scale = maxf(1.0, visible_size.x / readable_width)
	elif get_window().size.x < 1280:
		# At 640×480, expand still reports a 1280px-wide canvas. Keep controls
		# at native window size so its text remains legible instead of halving.
		ui_scale = maxf(1.0, visible_size.x / float(get_window().size.x))
	_root.scale = Vector2.ONE * ui_scale
	_root.size = visible_size / ui_scale
	var viewport_size := _root.size
	var compact := viewport_size.x < 850.0
	var portrait := viewport_size.x < viewport_size.y * 0.95
	var margin := (16.0 if viewport_size.x < 430 else 20.0) if compact else 32.0
	_top.add_theme_constant_override("margin_left", int(margin))
	_top.add_theme_constant_override("margin_right", int(margin))
	_top.add_theme_constant_override("margin_top", 16 if viewport_size.y < 650 else 24)
	_brand_sub.visible = viewport_size.x >= 530
	_brand_sub.get_parent().visible = viewport_size.x >= 480
	(_top.get_child(0) as HBoxContainer).add_theme_constant_override("separation", 8 if viewport_size.x < 600 else 14)
	_wardrobe_button.text = "衣橱  C" if compact else "猫咪衣橱  C"
	_wardrobe_button.custom_minimum_size.x = 84 if compact else 128
	var home_font_size := 56 if viewport_size.y < 520 else (64 if compact or viewport_size.y < 680 else 88)
	_home_title.add_theme_font_size_override("font_size", home_font_size)
	_home_subtitle.add_theme_font_size_override("font_size", 15 if compact else 18)
	_home.add_theme_constant_override("separation", 8 if viewport_size.y < 650 else 14)
	_home_note.visible = viewport_size.y >= 590
	_home.position = Vector2(margin + (8 if compact else 24), maxf(92.0, viewport_size.y * (0.20 if portrait else 0.19)))
	_home.size = Vector2(minf(470, viewport_size.x - margin * 2), 0)
	if portrait:
		_home_title.text = "喵跃云端"
		_home_title.add_theme_font_size_override("font_size", int(clampf((viewport_size.x - margin * 2) / 4.3, 40, 70)))
		_home.position.y = 112
	else:
		_home_title.text = "喵跃\n云端"
	_stage.position = Vector2(margin, viewport_size.y - 140 if viewport_size.x < 1100 else viewport_size.y - 115)
	_stage.size = Vector2(254, 76)
	_controls_label.text = "空格 跃向下一块 · 按住连跳 · WASD 移动" if compact else "WASD 移动   空格 跃向下一块   按住空格 连跳   鼠标拖动 视角   滚轮 缩放"
	_controls.size = Vector2(minf(650 if not compact else 390, viewport_size.x - margin * 2), 34)
	_controls.position = Vector2((viewport_size.x - _controls.size.x) * 0.5, viewport_size.y - 47)
	if home_visible and not portrait and viewport_size.x >= 1100:
		_controls.size.x = 580
		_controls.position.x = viewport_size.x - _controls.size.x - margin
	var modal_width := minf(820 if _modal_kind == "wardrobe" else 580, viewport_size.x - margin * 2)
	var modal_height := minf(590 if _modal_kind == "wardrobe" else 600, viewport_size.y - 70)
	_modal_panel.custom_minimum_size = Vector2(modal_width, 0)
	_modal_panel.size = Vector2(modal_width, modal_height)
	_modal_scroll.custom_minimum_size = Vector2(0, modal_height - 50)
	for grid_name: String in ["CatGrid", "OutfitGrid"]:
		var grid := _modal_content.get_node_or_null(grid_name) as GridContainer
		if grid:
			grid.columns = 5 if modal_width >= 650 else (3 if modal_width >= 430 else 2)
	var toast_width := minf(480, viewport_size.x - margin * 2)
	var text_height := _bold_font.get_multiline_string_size(_toast_label.text, HORIZONTAL_ALIGNMENT_CENTER, toast_width - 44, 15, 3).y
	_toast.size = Vector2(toast_width, clampf(ceilf(text_height) + 24, 48, 104))
	_toast.position = Vector2((viewport_size.x - _toast.size.x) * 0.5, 87)

func _label(text_value: String, font_size: int = 16, color: Color = INK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _bold_font)
	return label

func _button(text_value: String, color: Color, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _bold_font)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("aaa0a6"))
	button.add_theme_stylebox_override("normal", _style(color, 17, 15, 9, Color.TRANSPARENT, primary))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.09), 17, 15, 9, Color("d9b4c5"), primary))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.04), 17, 15, 9))
	button.add_theme_stylebox_override("disabled", _style(color.lightened(0.05), 17, 15, 9))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 17, 15, 9, Color("ae83b5")))
	return button

func _icon(kind: String, minimum: Vector2, tint: Color = Color("f3ac62")) -> TinyIcon:
	var icon := TinyIcon.new()
	icon.kind = kind
	icon.tint = tint
	icon.custom_minimum_size = minimum
	icon.size = minimum
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _style(color: Color, radius: int = 16, horizontal: int = 12, vertical: int = 8, border: Color = Color.TRANSPARENT, shadow: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	if border.a > 0:
		style.set_border_width_all(1)
		style.border_color = border
	if shadow:
		style.shadow_color = Color(0.30, 0.20, 0.30, 0.10)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 5)
	return style
