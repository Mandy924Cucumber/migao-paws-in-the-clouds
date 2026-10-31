@tool
extends EditorPlugin
## The editor's embedded game has its own sizing policy, separate from the
## project's canvas_items stretch mode. Configure this project to Stretch to Fit.
## Engine reference: editor/run/game_view_plugin.{h,cpp}, EmbedSizeMode = 2.

const STRETCH_TO_FIT: int = 2
const TOOL_LABEL: String = "恢复游戏窗口自适应"

func _enter_tree() -> void:
	add_tool_menu_item(TOOL_LABEL, _apply_window_fit)
	_apply_window_fit.call_deferred()

func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_LABEL)

func _apply_window_fit() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	settings.set_project_metadata("game_view", "embed_size_mode", STRETCH_TO_FIT)
	# GameView reads metadata only when it enters the editor tree. Activate its
	# existing menu action too, so enabling the plugin fixes the current session.
	# Match the menu labels, never a hard-coded node path or menu item ID.
	var menu: PopupMenu = _find_size_menu(get_tree().root)
	if menu == null:
		# Older Godot versions without embedded preview need no additional action.
		return
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Stretch to Fit":
			menu.id_pressed.emit(menu.get_item_id(i))
			return

func _find_size_menu(node: Node) -> PopupMenu:
	if node is PopupMenu:
		var has_fixed: bool = false
		var has_stretch: bool = false
		for i in range(node.item_count):
			has_fixed = has_fixed or node.get_item_text(i) == "Fixed Size"
			has_stretch = has_stretch or node.get_item_text(i) == "Stretch to Fit"
		if has_fixed and has_stretch:
			return node
	for child: Node in node.get_children(true):
		var found: PopupMenu = _find_size_menu(child)
		if found != null:
			return found
	return null
