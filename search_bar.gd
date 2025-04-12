extends LineEdit


@onready var popup_menu: PopupMenu = $PopupMenu

var search_room: Array[String] = []

var selected_idx := -1
var filtered_list = []

func _ready() -> void:
	# Grab focus when ready
	grab_focus()
	# When the text_changed signal is fired, filter the list
	text_changed.connect(_filter_list_and_popup)
	# start with the popup not being able to grab focus
	popup_menu.unfocusable = true

	# When the popup menu is about to popup make it focusable so we can control it with the mouse
	# connect it in a deferred way so it does it at the end of the frame and does not steal the focus
	popup_menu.about_to_popup.connect(func():
		popup_menu.unfocusable = false
	, CONNECT_DEFERRED)
	# When the popup menu is going to hide make it unfocusable again
	popup_menu.popup_hide.connect(func():
		popup_menu.unfocusable = true
	)

	# Connect the index_pressed to update_text
	popup_menu.index_pressed.connect(update_text)


func _gui_input(event: InputEvent) -> void:
	# If popup isn't visible, keep the normal behavior
	if not popup_menu.visible:
		return

	# if it's visible we check if the action is ui_up or ui_down
	# and act accordingly

	if event.is_action_pressed("ui_up", true):
		# wrap the selected_idx up, focus the item in the popup and accept the event
		selected_idx = wrapi(selected_idx - 1, 0, filtered_list.size())
		popup_menu.set_focused_item(selected_idx)
		accept_event()
	if event.is_action_pressed("ui_down", true):
		# wrap the selected_idx down, focus the item in the popup and accept the event
		selected_idx = wrapi(selected_idx + 1, 0, filtered_list.size())
		popup_menu.set_focused_item(selected_idx)
		accept_event()
	if event.is_action_pressed("ui_accept"):
		# update the text to the selected index, hide the popup and accept the event
		update_text(selected_idx)
		popup_menu.hide()
		accept_event()


func update_text(index:int) -> void:
	# set the text to the filtered list value and se the caret column to the end of the text
	text = filtered_list[index]
	caret_column = text.length()
	text_submitted.emit(text)


func _filter_list_and_popup(input_text:String) -> void:
	if input_text.length() < 2:
		# if input_text is less than 2 characters hide the popup and set the selected index to -1
		popup_menu.hide()
		selected_idx = -1
		return

	# generate the filtered list by sorting the FRUITS list checking their similarity with the input_text
	filtered_list = search_room.duplicate()
	filtered_list.sort_custom(func(a:String, b:String): return a.similarity(input_text) > b.similarity(input_text))

	# Resize it to the first 10 values
	filtered_list.resize(10)

	# clear the popup list and fill it
	popup_menu.clear()
	for value in filtered_list:
			popup_menu.add_item(value)

	if not popup_menu.visible:
		# if the popup is not visible, make it popup at the bottom of the line edit
		popup_menu.popup(Rect2(position + Vector2(0, size.y + 2), size))

	# select the first value and focus it
	selected_idx = 0
	popup_menu.set_focused_item(selected_idx)
