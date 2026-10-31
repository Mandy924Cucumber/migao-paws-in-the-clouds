extends RefCounted
## A versioned, atomic local save. Currency can only be earned once per pickup.

const SAVE_PATH := "user://paws_save_v1.json"
const CATS := ["orange", "white", "gray", "brown", "ragdoll"]
const PRICES := {"mint_scarf": 8, "berry_cap": 12, "star_cape": 18, "crown": 25}
var food: int = 0
var lifetime_food: int = 0
var cat_id: String = "orange"
var outfit_id: String = "none"
var owned: Array[String] = ["none"]
var collected: Array[int] = []
var checkpoint: int = 0
var best_platform: int = 0
var finished: bool = false
var muted: bool = false
var persistent: bool = true
var save_path: String = SAVE_PATH

func load_game() -> void:
	if not persistent or not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	apply_data(data)

func apply_data(data: Dictionary) -> void:
	food = clampi(_number(data.get("food", 0)), 0, 999999)
	lifetime_food = clampi(_number(data.get("lifetime_food", food), food), food, 999999)
	var saved_cat: String = str(data.get("cat_id", "orange"))
	cat_id = saved_cat if saved_cat in CATS else "orange"
	owned.assign(["none"])
	var saved_owned: Variant = data.get("owned", [])
	if saved_owned is Array:
		for item: Variant in saved_owned:
			if str(item) in PRICES and not str(item) in owned:
				owned.append(str(item))
	var saved_outfit: String = str(data.get("outfit_id", "none"))
	outfit_id = saved_outfit if saved_outfit in owned else "none"
	checkpoint = clampi(int(_number(data.get("checkpoint", 0)) / 7.0) * 7, 0, 35)
	best_platform = clampi(_number(data.get("best_platform", checkpoint), checkpoint), checkpoint, 42)
	collected.clear()
	var saved_collected: Variant = data.get("collected", [])
	if saved_collected is Array:
		for item: Variant in saved_collected:
			var index: int = _number(item, -1)
			if index > 0 and index <= 42 and not index in collected:
				collected.append(index)
	finished = data.get("finished", false) == true
	muted = data.get("muted", false) == true

func _number(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return clampi(value, -1000000000, 1000000000)
	if value is float and is_finite(value):
		return int(clampf(value, -1000000000.0, 1000000000.0))
	if value is String and value.is_valid_int():
		return clampi(value.to_int(), -1000000000, 1000000000)
	return fallback

func save_game() -> void:
	if not persistent:
		return
	var data := {"version": 1, "food": food, "lifetime_food": lifetime_food, "cat_id": cat_id,
		"outfit_id": outfit_id, "owned": owned, "collected": collected, "checkpoint": checkpoint,
		"best_platform": best_platform, "finished": finished, "muted": muted}
	var temp: String = save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("无法保存进度：" + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(save_path))
	if result != OK:
		push_warning("无法写入存档：" + str(result))

func collect(index: int, amount: int = 3) -> bool:
	if index <= 0 or index > 42 or amount <= 0 or index in collected:
		return false
	collected.append(index)
	food += amount
	lifetime_food += amount
	save_game()
	return true

func purchase(item: String) -> bool:
	if not item in PRICES or item in owned or food < int(PRICES[item]):
		return false
	food -= int(PRICES[item])
	owned.append(item)
	outfit_id = item
	save_game()
	return true

func state() -> Dictionary:
	return {"food": food, "cat_id": cat_id, "outfit_id": outfit_id, "owned": owned.duplicate(),
		"prices": PRICES.duplicate(), "lifetime_food": lifetime_food, "finished": finished}
