class_name Main extends Node

const ALL_RECIPES := preload("res://ingredients/all_recipes.tres")

@onready var _search := %search
@onready var _count: SpinBox = %count
@onready var _list: ItemList = %list
@onready var _tree: Tree = %tree
@onready var _machines: ItemList = %machines
@onready var _graph: GraphEdit = %graph

var _current_recipe: Recipe = null

func _ready() -> void:
	_populate_search_list()

func _populate_search_list() -> void:
	_search.search_room = ALL_RECIPES.paths

func _add_all_files(dir: String, list: Array[String]) -> void:
	for path: String in DirAccess.get_directories_at(dir):
		_add_all_files(dir.path_join(path), list)
	
	for file: String in DirAccess.get_files_at(dir):
		list.append(dir.path_join(file))

func _populate() -> void:
	_populate_items()
	_populate_tree()
	_populate_machines()
	_populate_graph()

func _populate_graph() -> void:
	for child: Node in _graph.get_children():
		if child is GraphNode:
			child.free()
	
	if _current_recipe == null:
		return
	
	var prototypes: Dictionary[StringName, Recipe] = {}
	_current_recipe.get_prototypes(prototypes)
	
	var dict := _current_recipe.fetch_flat(true)
	
	_add_graph_nodes.call_deferred(prototypes, dict)
	
	_connect_graph.call_deferred(prototypes, dict)

func _add_graph_nodes(
	prototypes: Dictionary[StringName, Recipe],
	dict: Dictionary[StringName, float]
) -> void:
	for recipe: StringName in dict:
		_graph.add_child(
			_get_graph_node(prototypes[recipe], dict[recipe])
		)

func _connect_graph(
	prototypes: Dictionary[StringName, Recipe],
	dict: Dictionary[StringName, float]
	) -> void:
	for child_name: StringName in dict:
		var recipe: Recipe = prototypes[child_name]
		for i: int in range(recipe.get_child_count(true)):
			var child: Recipe = recipe.get_child(i)
			
			_graph.connect_node(
				child.name,
				0,
				recipe.name,
				i
			)
	
	_graph.arrange_nodes()

func _get_recipe_color(recipe_name: StringName) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = recipe_name.hash()
	return Color(
		rng.randf(),
		rng.randf(),
		rng.randf()
	)

func _format_count_string(recipe: Recipe, count: float) -> String:
	if recipe.fluid:
		return "%.3f" % count
	
	var ceiled: int = int(ceil(count))
	if ceiled < 64:
		return str(ceiled)
	
	var m := ceiled % 64
	var c := ceiled / 64
	if m == 0:
		return "%d x64" % c
	
	return "%d x64 + %d" % [c, m]

func _get_graph_node(recipe: Recipe, count: float) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = recipe.name
	
	if recipe.base_component:
		graph_node.title = "Input"
	else:
		graph_node.title = Recipe.MachineType.keys()[recipe.machine_type]
	
	graph_node.set_slot_enabled_right(0, true)
	graph_node.set_slot_color_right(0, _get_recipe_color(recipe.name))
	graph_node.set_slot_type_right(0, 2)
	
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = "%s %s" % [recipe.name, _format_count_string(recipe, count)]
	graph_node.add_child(label)
	
	var child_count := recipe.get_child_count(true)
	for i: int in range(child_count):
		var r: Recipe = recipe.get_child(i)
		var color := _get_recipe_color(r.name)
		graph_node.set_slot(
			i + 1,
			true,
			2,
			color,
			false,
			2,
			color
		)
		
		label = Label.new()
		var child: Recipe = recipe.get_child(i)
		label.text = "%s %s" % [child.name, _format_count_string(child, child.count * count)]
		graph_node.add_child(label)
	
	return graph_node

func _populate_items() -> void:
	_list.clear()
	
	if _current_recipe == null:
		return
	
	var dict := _current_recipe.fetch_flat()
	for recipe: StringName in dict:
		var text: String = "%s: %f" % [recipe, dict[recipe]]
		_list.add_item(text)

func _populate_machines() -> void:
	_machines.clear()
	
	if _current_recipe == null:
		return
	
	var machines: Dictionary[int, Dictionary] = {}
	_current_recipe.transfer_machine(machines)
	
	for machine: Dictionary in machines.values():
		var text: String = "%s %s with mode %s" % [
			machine["tier"],
			machine["type"],
			machine["mode"]
		]
		_machines.add_item(text)

func _populate_tree() -> void:
	_tree.clear()
	
	if _current_recipe == null:
		return
	
	var root = _tree.create_item()
	_set_tree_item(_tree, root, _current_recipe, 1.0)

func _set_tree_item(tree: Tree, item: TreeItem, recipe: Recipe, parent_count: float) -> void:
	item.set_text(0, recipe.name)
	item.set_text(1, "%f" % (recipe.count * parent_count))
	
	for child: Recipe in recipe.get_children(true):
		_set_tree_item(tree, tree.create_item(item), child, recipe.count * parent_count)

func _on_count_value_changed(value: float) -> void:
	if _current_recipe == null:
		return
	
	if not is_equal_approx(_current_recipe.count, value):
		_current_recipe.count = value
		_populate()


func _on_search_text_submitted(new_text: String) -> void:
	if not FileAccess.file_exists(new_text):
		return
	
	if _current_recipe != null:
		if _current_recipe.scene_file_path == new_text:
			return
		
		_current_recipe.queue_free()
	
	var packed: PackedScene = load(new_text)
	var scene: Recipe = packed.instantiate()
	add_child(scene)
	_current_recipe = scene
	_current_recipe.count = _count.value
	
	_populate()
