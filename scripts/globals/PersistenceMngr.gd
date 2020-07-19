tool
extends Node

# PersistenceManager is stores a Dictionary for state objects that should
# be stored and saved to the disc.
# Each PersistentObject has a UID as a key and a Dictionary for its data
# 
# Use
#	get_val(uid:String)
#	set_val(uid:String, val)
# to access the entire Dictionary
# e.g.: get_val("settingsAudio").Master == 100
#
# Use
#	get_val_from_ui_path(uid_path:String)
#	set_val_from_ui_path(uid_path:String, val)
# to access only subparts of the Dictionary given a dot-separated uid_path
# e.g.: get_val_from_ui_path("settingsAudio.Master") == 100

var _objs = {}

func _ready():
	if C.remove_all_saves:
		for obj in _objs.values():
			obj._remove_save()
#############################################################
# GETTERS

# Gets a PersistenceObject from a given uid,
# And NOT the saved state itself
# for example:	var master = get_obj("settingsAudio").get_val().Master
func get_obj(uid:String):
	if has_obj(uid):
		return _objs[uid]
	else:
		D.e(D.LogCategory.PERSISTENCE, ["Could not get PersistentObj [", "UID:", uid, "]" ])
		return null

# Gets a saved state of a PersistenceObject from a given uid,
# for example:	var master = get_val("settingsAudio").Master
func get_val(uid:String):
	var obj = get_obj(uid)
	if obj:
		return obj.get_val()

# Gets a saved state of a PersistenceObject from a given uid path,
# for example:	var master = get_val_from_ui_path("settingsAudio.Master")
func get_val_from_ui_path(uid_path:String):
	
	var nodes = uid_path.split(".")
	
	# Cancel if uid_path has length 0
	if nodes.size() == 0:
		D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path [", "UID-Path:", uid_path, "]" ])
		return null
	
	# Cancel if uid_paths first node doesnt exists
	var val = get_val(nodes[0])
	if val == null:
		D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path, invalid Node in Path [", "UID-Path:", uid_path, ",", "Node:", nodes[0], "]" ])
		return null
	
	# Iterate through json
	for i in range(1, nodes.size()):
		var node = nodes[i]
		if val.has(node):
			val = val[node]
		else:
			D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path, invalid Node in Path [", "UID-Path:", uid_path, ",", "Node:", node, "]" ])
			return null
	return val
	

#############################################################
# SETTERS

# Sets the state of a PersistenceObject given uid to a given val
# for example:	set_val("settingsAudio", {"Master":100})
func set_val(uid:String, val):
	if has_obj(uid):
		return _objs[uid].set_val(val)
		
# Sets the state of a PersistenceObject given uid path to a given val
# for example:	set_val_from_ui_path("settingsAudio.Master", 100)
func set_val_from_ui_path(uid_path:String, val):
	var nodes = uid_path.split(".")
	if nodes.size() == 0:
		D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path [", "UID-Path:", uid_path, "]" ])
	elif nodes.size() == 1:
		set_val(uid_path, val)
	else:
		# First node is entire json
		var entire_obj = get_obj(nodes[0])
		if entire_obj == null:
			D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path, invalid Node in Path [", "UID-Path:", uid_path, ",", "Node:", nodes[0], "]" ])
			return false
		var cur_val = entire_obj.get_val()
		
		# Then iterate from [1, size()-2] to find last branch
		for i in range(1, max(1, nodes.size()-1)):
			var node = nodes[i]
			if cur_val.has(node):
				cur_val = cur_val[node]
			else:
				D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path, invalid Node in Path [", "UID-Path:", uid_path, ",", "Node:", node, "]" ])
				return false
		
		# Perform set operation
		var last_node = nodes[nodes.size()-1]
		if cur_val.has(last_node):
			cur_val[last_node] = val
		else:
			D.e(D.LogCategory.PERSISTENCE, ["Could not parse uid path, invalid Node in Path [", "UID-Path:", uid_path, ",", "Node:", last_node, "]" ])
			return false
		
		# If no error: trigger_update
		entire_obj.trigger_update()
		return true
	
#############################################################
# ADDING

# Adds/Overrides a PersistentObj given persistentObj.uid
func add_obj(persistentObj):
	_objs[persistentObj.uid] = persistentObj
	
# Checks for existence of PersistentObj given a uid
func has_obj(uid:String):
	return uid in _objs

func connect_to_persistent_obj(uid, cb_context, cb_method):
	get_obj(uid).connect("changed", cb_context, cb_method)

	
#############################################################
# SUB-CLASS	
class PersistentObj:
	
	signal changed(new_val)
	var uid
	var default
	var val = null
	
	var flags
	const LOAD_ON_START = 1
	const SAVE_ON_SET = 2
	
	func _init(uid, default, flags=SAVE_ON_SET):
		self.uid = uid
		self.default = default
		self.flags = flags
		
		# Initially load if flag set:
		if flags & LOAD_ON_START:
			get_val()
	
	#############################################################
	# SAVING

	func _get_save_path()->String:
		return "user://save_" + uid + ".save"
		
	func _does_save_exist()->bool:
		var dir:Directory = Directory.new()
		return dir.file_exists(_get_save_path())
	
	func _remove_save():
		if _does_save_exist():
			var dir:Directory = Directory.new()
			dir.remove(_get_save_path())
			val = default
	
	func _to_string()->String:
		return JSON.print(val)
		
	func _save()->bool:
		var file:File = File.new()
		if file.open(_get_save_path(), File.WRITE) == OK:
			var string = _to_string()
			file.store_string(string)
			D.l(D.LogCategory.PERSISTENCE, ["Wrote save [", "UID:", uid, ",", "Data:", string, "]" ])
			return true
		else:
			D.e(D.LogCategory.PERSISTENCE, ["Error opening PersistentObj File for writing [", "UID:", uid, "]" ])
		return false
	
	#############################################################
	# LOADING
		
	func _load_from_string(string:String)->bool:
		var json_result = JSON.parse(string)
		if json_result.error == OK:
			val = json_result.result
			return true
		else:
			D.e(D.LogCategory.PERSISTENCE, ["Error parsing PersistentObj from json [", "UID:", uid, ",", "str:", string, "]" ])
			return false
		
	func _load_from_save()->bool:
		if _does_save_exist():
			var file:File = File.new()
			if file.open(_get_save_path(), File.READ) == OK:
				var string = file.get_as_text()
				if _load_from_string(string):
					D.l(D.LogCategory.PERSISTENCE, ["Loaded save [", "UID:", uid, ",", "Data:", val, "]" ])
					return true
			else:
				D.e(D.LogCategory.PERSISTENCE, ["Error opening PersistentObj File [", "UID:", uid, "]" ])
		return false
	
	#############################################################
	# INTERFACE
	
	# Singleton Function that
	#	* Ensures existence of one and only value
	#	* Loads from a File if not existent
	#	* Uses a default value otherwise
	func get_val():
		
		# Prevent actual loading in EditorMode, and just use default
		if Engine.is_editor_hint():
			val = default
		
		# 1: Try if local reference exists
		if val != null:
			pass
		
		# 2: Try loading from save file
		elif _does_save_exist():
			_load_from_save()
		
		# 3: Use default value else
		else:
			val = default
		
		return val
	
	# Sets the saved value of this PersistentObj
	# triggers_update to save to file if SAVE_ON_SET is set
	func set_val(val):
		self.val = val
		trigger_update()
	
	# Gives a change to save if flag SAVE_ON_SET is set
	func trigger_update():
		emit_signal("changed", get_val())
		# Save if flag set
		if flags & SAVE_ON_SET:
			_save()