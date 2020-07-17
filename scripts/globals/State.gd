tool
extends Node

#############################################################
# NON PERSISTANT STATE
onready var score = StateInt.new(0)

#############################################################
# PERSISTANT STATE
func _ready():
	var settingsAudio = PersistenceManager.PersistentObj.new("settingsAudio", {
		"Master" : 80,
		"Music" : 100,
		"Effects" : 100
	})
	settingsAudio.connect("changed", self, "_on_settingsAudio_update")
	PersistenceManager.add_obj(settingsAudio)
	
	
	var settingsControls = PersistenceManager.PersistentObj.new("settingsControls", {
		"Left" : 65,
		"Right" : 68,
		"Up" : 87,
		"Down" : 83,
		"Jump" : 32,
		"PrevDemo" : 52,
		"NextDemo" : 82,
		"PrevSkin" : 53,
		"NextSkin" : 84,
		"Pause" : 80,
		"Interact" : 16777221
	})
	settingsControls.connect("changed", self, "_on_settingsControls_update")
	PersistenceManager.add_obj(settingsControls)
	
	# Inititally configure audio and controls
	settingsAudio.trigger_update()
	settingsControls.trigger_update()

#############################################################
# HANDLERS FOR PERSISTENT STATE
func _on_settingsAudio_update(settingsAudio):
	for bus in settingsAudio.keys():
		var idx = AudioServer.get_bus_index(bus)
		if idx != -1:
			var vol = settingsAudio[bus]
			# 0 => -80, 100 => 0
			var db = -80 * (1 - (vol / 100.0))
			AudioServer.set_bus_volume_db(idx, db)
			
func _on_settingsControls_update(settingsControls):
	D.l("Controls", ["Configured Controls to be", settingsControls])
	for input_action in settingsControls.keys():
		var scancode = settingsControls[input_action]
		
		# Add this keybind in case it doesn't exist
		if !InputMap.has_action(input_action):
			InputMap.add_action(input_action)
			
		# Erase any already bound events from this input_action
		InputMap.action_erase_events(input_action)
		
		# Add new event to input_action if assigned scancode
		if scancode != null:
			var key_event = InputEventKey.new()
			key_event.set_scancode(scancode)
			InputMap.action_add_event(input_action, key_event)

#############################################################
# NOTITFYING State Object
class StateInt:
	signal state_changed(new_state)
	var state setget _set_state
	func _set_state(v):
		state = v
		emit_signal("state_changed", state)
	func _init(state):
		self.state = state
