extends SceneTree
## Standalone, deterministic tests. No user:// reads, writes, or save deletion.
## File round trips use a uniquely named temporary cache file and clean it up.
## Run: godot --headless --path . --script res://tests/save_test.gd

const SaveData = preload("res://scripts/save_data.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_defaults_and_disabled_persistence()
	_test_collection()
	_test_purchase()
	_test_sanitization()
	_test_json_types()
	_test_state_snapshot()
	_test_atomic_roundtrip()
	if failures.is_empty():
		print("SAVE TEST PASS: %d checks; player save untouched; temporary roundtrip cleaned up" % checks)
		quit(0)
	else:
		for message: String in failures:
			push_error("SAVE TEST FAILED: " + message)
		print("SAVE TEST FAILED: %d / %d checks" % [failures.size(), checks])
		quit(1)

func _fresh():
	var data = SaveData.new()
	data.persistent = false
	return data

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _test_defaults_and_disabled_persistence() -> void:
	var data = _fresh()
	_check(data.food == 0 and data.lifetime_food == 0, "New save starts with no food")
	_check(data.cat_id == "orange" and data.outfit_id == "none", "Default appearance is the orange cat")
	_check(data.owned == ["none"] and data.collected.is_empty(), "New save has no purchases or pickups")
	_check(data.checkpoint == 0 and data.best_platform == 0, "New save starts on the first burger")
	data.food = 17
	data.save_game()
	data.load_game()
	_check(data.food == 17 and not data.persistent, "Disabled persistence preserves in-memory state without loading a real save")

func _test_collection() -> void:
	var data = _fresh()
	_check(data.collect(1), "First valid pickup is accepted")
	_check(data.food == 3 and data.lifetime_food == 3, "Default pickup grants three food")
	_check(not data.collect(1), "The same pickup cannot be collected twice")
	_check(data.food == 3 and data.lifetime_food == 3 and data.collected == [1], "Duplicate pickup changes no balances or IDs")
	_check(data.collect(3, 6), "A second pickup can specify its reward")
	_check(data.food == 9 and data.lifetime_food == 9, "Multiple rewards update current and lifetime balances")
	for index: int in [-1, 0, 43, 999999]:
		_check(not data.collect(index), "Invalid pickup index %d is rejected" % index)
	for amount: int in [0, -3]:
		_check(not data.collect(5, amount), "Nonpositive pickup amount %d is rejected" % amount)
	_check(data.food == 9 and data.collected == [1, 3], "Rejected pickups leave state intact")

func _test_purchase() -> void:
	var data = _fresh()
	_check(not data.purchase("mint_scarf"), "Insufficient funds do not buy a scarf")
	_check(data.food == 0 and data.owned == ["none"], "Failed purchase leaves balance and ownership intact")
	data.food = 72
	data.lifetime_food = 72
	for id: String in ["", "unknown", "orange", "none"]:
		_check(not data.purchase(id), "Invalid outfit ID '%s' is rejected" % id)
	_check(data.food == 72 and data.outfit_id == "none", "Invalid IDs do not spend money or equip anything")
	for id: String in ["mint_scarf", "berry_cap", "star_cape", "crown"]:
		var before: int = data.food
		var price: int = SaveData.PRICES[id]
		_check(data.purchase(id), "Affordable outfit '%s' can be purchased" % id)
		_check(data.food == before - price and data.outfit_id == id and id in data.owned, "Purchase '%s' deducts exact price and equips" % id)
		_check(not data.purchase(id) and data.food == before - price, "Already owned outfit '%s' cannot charge twice" % id)
	_check(data.food == 9 and data.lifetime_food == 72, "Buying all outfits costs 63 and preserves lifetime food")

func _test_sanitization() -> void:
	var data = _fresh()
	data.apply_data({"food": -10, "lifetime_food": -30, "cat_id": "unknown", "outfit_id": "crown",
		"owned": ["none", "mint_scarf", "mint_scarf", "unknown"],
		"collected": [-1, 0, 1, 1, 3, 42, 43], "checkpoint": 16, "best_platform": 2})
	_check(data.food == 0 and data.lifetime_food == 0, "Negative balances sanitize to zero")
	_check(data.cat_id == "orange", "Unknown cat falls back to orange")
	_check(data.owned == ["none", "mint_scarf"], "Owned outfits remove unknown IDs and duplicates")
	_check(data.outfit_id == "none", "Unowned saved outfit cannot be equipped")
	_check(data.collected == [1, 3, 42], "Saved pickup IDs remove duplicates and out-of-range IDs")
	_check(data.checkpoint == 14 and data.best_platform == 14, "Checkpoint aligns to previous burger; best cannot trail checkpoint")
	data.apply_data({"food": 9999999999, "lifetime_food": 1, "checkpoint": 9999, "best_platform": 9999,
		"cat_id": "ragdoll", "owned": ["crown"], "outfit_id": "crown"})
	_check(data.food == 999999 and data.lifetime_food >= data.food, "Excessive balance clamps and lifetime cannot trail balance")
	_check(data.checkpoint == 35 and data.best_platform == 42, "Progress clamps to supported platform range")
	_check(data.cat_id == "ragdoll" and data.outfit_id == "crown", "Valid saved appearance survives normalization")
	data.apply_data({"checkpoint": -35, "best_platform": -99})
	_check(data.checkpoint == 0 and data.best_platform == 0, "Negative progress returns to the first checkpoint")
	data.apply_data({})
	_check(data.food == 0 and data.lifetime_food == 0 and data.owned == ["none"] and data.collected.is_empty(), "An empty save restores collection and economy defaults")
	_check(data.cat_id == "orange" and data.outfit_id == "none" and not data.finished and not data.muted, "An empty save restores appearance and option defaults")

func _test_json_types() -> void:
	var data = _fresh()
	# JSON objects may be corrupt but should never reach unsafe numeric casts.
	for value: Variant in [null, [], {}, "not a number"]:
		data.apply_data({"food": value, "lifetime_food": value, "checkpoint": value, "best_platform": value,
			"owned": value, "collected": value, "cat_id": value, "outfit_id": value})
		_check(data.food == 0 and data.lifetime_food == 0 and data.checkpoint == 0 and data.best_platform == 0, "Malformed JSON numeric fields sanitize to safe defaults: " + str(value))
		_check(data.owned == ["none"] and data.collected.is_empty() and data.cat_id == "orange" and data.outfit_id == "none", "Malformed JSON identifiers and collections are safe: " + str(value))
	data.apply_data({"collected": [null, {}, [], "bad", 1, 1, 42], "owned": [null, {}, [], "crown", "crown"]})
	_check(data.collected == [1, 42] and data.owned == ["none", "crown"], "Malformed entries inside JSON lists are ignored")

func _test_state_snapshot() -> void:
	var data = _fresh()
	data.food = 20
	data.purchase("mint_scarf")
	var snapshot: Dictionary = data.state()
	var snapshot_owned: Array = snapshot["owned"]
	var snapshot_prices: Dictionary = snapshot["prices"]
	snapshot_owned.append("fake_outfit")
	snapshot_prices["mint_scarf"] = 0
	snapshot["food"] = 0
	_check(not "fake_outfit" in data.owned, "Mutating snapshot ownership cannot change save ownership")
	_check(SaveData.PRICES["mint_scarf"] == 8, "Mutating snapshot prices cannot change game prices")
	_check(data.food == 12, "Mutating snapshot balance cannot change save balance")

func _test_atomic_roundtrip() -> void:
	var path: String = OS.get_cache_dir().path_join("paws-save-test-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".tmp"):
		_check(false, "Roundtrip temporary path must not already exist")
		return
	var writer = _fresh()
	writer.save_path = path
	writer.persistent = true
	writer.apply_data({"food": 64, "lifetime_food": 72, "cat_id": "ragdoll", "outfit_id": "mint_scarf",
		"owned": ["none", "mint_scarf"], "collected": [1, 3, 14], "checkpoint": 14,
		"best_platform": 19, "finished": true, "muted": true})
	writer.save_game()
	_check(FileAccess.file_exists(path), "Atomic save creates the requested isolated file")
	_check(not FileAccess.file_exists(path + ".tmp"), "Successful atomic save consumes its staging file")
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary and parsed.get("version") == 1, "Written save is valid versioned JSON")
	var reader = _fresh()
	reader.save_path = path
	reader.persistent = true
	reader.load_game()
	_check(reader.food == 64 and reader.lifetime_food == 72, "Current and lifetime food survive disk roundtrip")
	_check(reader.cat_id == "ragdoll" and reader.outfit_id == "mint_scarf", "Cat and equipped outfit survive disk roundtrip")
	_check(reader.owned == ["none", "mint_scarf"] and reader.collected == [1, 3, 14], "Purchases and pickup IDs survive disk roundtrip")
	_check(reader.checkpoint == 14 and reader.best_platform == 19, "Checkpoint and best progress survive disk roundtrip")
	_check(reader.finished and reader.muted, "Completion and mute preferences survive disk roundtrip")
	writer.purchase("berry_cap")
	writer.collect(5)
	writer.checkpoint = 21
	writer.best_platform = 26
	writer.save_game()
	reader.load_game()
	_check(reader.food == 55 and reader.lifetime_food == 75 and reader.outfit_id == "berry_cap", "Atomic replacement preserves updated purchases and earnings")
	_check(reader.checkpoint == 21 and reader.best_platform == 26 and reader.collected == [1, 3, 14, 5], "Atomic replacement preserves new checkpoint and pickup history")
	_check(not reader.collect(5) and not reader.purchase("berry_cap"), "Reloaded pickup and purchase history still rejects duplicates")
	_check(not FileAccess.file_exists(path + ".tmp"), "Repeated successful saves leave no staging file")
	# A non-object JSON document must not partially mutate loaded state.
	var malformed := FileAccess.open(path, FileAccess.WRITE)
	if malformed != null:
		malformed.store_string("[]")
		malformed.close()
		reader.load_game()
		_check(reader.food == 55 and reader.checkpoint == 21, "A non-object JSON save leaves existing state intact")
	else:
		_check(false, "Can open the isolated file for malformed-JSON test")
	if FileAccess.file_exists(path):
		_check(DirAccess.remove_absolute(path) == OK, "Roundtrip save file is removed at completion")
	if FileAccess.file_exists(path + ".tmp"):
		_check(DirAccess.remove_absolute(path + ".tmp") == OK, "Any failed staging file is removed at completion")
