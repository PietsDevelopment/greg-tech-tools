@tool
class_name Recipe extends Node

enum MachineType {
	CHEMICAL_REACTOR,
	FLUID_SOLIDIFIER,
	FLUID_EXTRACTOR,
	CIRCUIT_ASSEMBLER,
	BENDING_MACHINE,
	CUTTING_MACHINE,
	LASER_ENGRAVER,
	WIRE_MILL,
	ALLOY_SMELTER,
	ASSEMBLER,
	EXTRUDER,
	POLARIZER,
	COMPRESSOR,
	ARC_FURNACE
}

enum Tier {
	LV,
	MV,
	HV,
	EV
}

@export var count: float = 1:
	get:
		return input_to_output.x / input_to_output.y
	set(value):
		input_to_output.x = value
		input_to_output.y = 1.0
		count = value

@export_custom(PROPERTY_HINT_LINK, "") var input_to_output: Vector2 = Vector2.ONE

@export var fluid: bool = false

@export var base_component: bool = false

@export_group("Machine", "machine_")
@export var machine_type: MachineType
@export var machine_tier: Tier
@export var machine_mode: String

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if abs(count - (input_to_output.x / input_to_output.y)) > 0.1:
		push_warning("Input to Output not set right on " + name)
	
	for warning: String in _get_configuration_warnings():
		push_warning(name + warning)

func transfer_machine(dict: Dictionary[int, Dictionary]) -> void:
	if get_child_count(true) == 0:
		return
	
	var machine: Dictionary = {
		"type": MachineType.keys()[machine_type],
		"tier": Tier.keys()[machine_tier],
		"mode":machine_mode
	}
	
	var hash_code: int = machine.hash()
	if not dict.has(hash_code):
		dict[hash_code] = machine
	
	for child: Recipe in get_children(true):
		child.transfer_machine(dict)

func get_prototypes(dict: Dictionary[StringName, Recipe]) -> void:
	if not dict.has(self.name):
		dict[self.name] = self
	
	for child: Recipe in get_children(true):
		child.get_prototypes(dict)

func fetch_flat(collect_intermediates: bool = false) -> Dictionary[StringName, float]:
	if get_child_count(true) == 0:
		return {name:count}
	
	var result: Dictionary[StringName, float] = {}
	for child: Recipe in get_children(true):
		var dict: Dictionary[StringName, float] = child.fetch_flat(collect_intermediates)
		
		for key: StringName in dict:
			if result.has(key):
				result[key] += dict[key]
			else:
				result[key] = dict[key]
	
	for key: StringName in result:
		result[key] *= count
	
	if collect_intermediates:
		result[name] = count
	
	return result

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if get_child_count(true) == 0 and not base_component:
		warnings.append("Recipes must have input components. Should this be a base component?")
	
	if base_component:
		if machine_type != 0 or machine_tier != 0 or machine_mode != "":
			warnings.append("Base components should not override machine information.")
	
	return warnings
