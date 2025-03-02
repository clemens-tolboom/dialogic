tool
extends Tree

onready var editor_reference = get_node('../../../')
onready var timeline_editor = get_node('../../TimelineEditor')
onready var character_editor = get_node('../../CharacterEditor')
onready var definition_editor = get_node('../../DefinitionEditor')
onready var settings_editor = get_node('../../SettingsEditor')
onready var theme_editor = get_node('../../ThemeEditor')
onready var empty_editor = get_node('../../Empty')
onready var filter_tree_edit = get_node('../FilterMasterTreeEdit')

onready var tree = self

var timeline_icon
var character_icon
var theme_icon
var definition_icon
var glossary_icon

var timelines_tree
var characters_tree
var definitions_tree
var themes_tree
var settings_tree


var item_path_before_edit = ""

# dragging items
var dragging_item = null
var drag_preview = load("res://addons/dialogic/Editor/MasterTree/DragPreview.tscn")

var rmb_popup_menus = {}

var filter_tree_term = ''

signal editor_selected(selected)

func _ready():
	allow_rmb_select = true
	var root = tree.create_item()
	tree.set_hide_root(true)
	
	var modifier = ''
	var _scale = get_constant("inspector_margin", "Editor")
	_scale = _scale * 0.125
	rect_min_size.x = 150
	if _scale == 1.25:
		modifier = '-1.25'
		rect_min_size.x = 180
	if _scale == 1.5:
		modifier = '-1.25'
		rect_min_size.x = 250
	if _scale == 1.75:
		modifier = '-1.25'
		rect_min_size.x = 250
	if _scale == 2:
		modifier = '-2'
		rect_min_size.x = 360
	rect_size.x = 0
	timeline_icon = load("res://addons/dialogic/Images/Resources/timeline" + modifier + ".svg")
	character_icon = load("res://addons/dialogic/Images/Resources/character" + modifier + ".svg")
	theme_icon = load("res://addons/dialogic/Images/Resources/theme" + modifier + ".svg")
	definition_icon = load("res://addons/dialogic/Images/Resources/definition" + modifier + ".svg")
	glossary_icon = get_icon("ListSelect", "EditorIcons")
	
	# Creating the root items
	timelines_tree = tree.create_item(root)
	timelines_tree.set_text(0, "Timelines")
	timelines_tree.set_icon(0, get_icon("Folder", "EditorIcons"))
	timelines_tree.set_icon_modulate(0, get_color("folder_icon_modulate", "FileDialog"))
	timelines_tree.collapsed = DialogicUtil.get_folder_meta('Timelines', 'folded')
	timelines_tree.set_metadata(0, {'editor': 'Timeline Root'})
	
	characters_tree = tree.create_item(root)
	characters_tree.set_text(0, "Characters")
	characters_tree.set_icon(0, get_icon("Folder", "EditorIcons"))
	characters_tree.set_icon_modulate(0, get_color("folder_icon_modulate", "FileDialog"))
	characters_tree.collapsed = DialogicUtil.get_folder_meta('Characters', 'folded')
	characters_tree.set_metadata(0, {'editor': 'Character Root'})

	definitions_tree = tree.create_item(root)
	definitions_tree.set_text(0, "Definitions")
	definitions_tree.set_icon(0, get_icon("Folder", "EditorIcons"))
	definitions_tree.set_icon_modulate(0, get_color("folder_icon_modulate", "FileDialog"))
	definitions_tree.collapsed = DialogicUtil.get_folder_meta('Definitions', 'folded')
	definitions_tree.set_metadata(0, {'editor': 'Definition Root'})
	
	themes_tree = tree.create_item(root)
	themes_tree.set_text(0, "Themes")
	themes_tree.set_icon(0, get_icon("Folder", "EditorIcons"))
	themes_tree.set_icon_modulate(0, get_color("folder_icon_modulate", "FileDialog"))
	themes_tree.collapsed = DialogicUtil.get_folder_meta('Themes', 'folded')
	themes_tree.set_metadata(0, {'editor': 'Theme Root'})
	
	settings_tree = tree.create_item(root)
	settings_tree.set_text(0, "Settings")
	settings_tree.set_icon(0, get_icon("GDScript", "EditorIcons"))
	settings_tree.set_metadata(0, {'editor': 'Settings'})
	
	# creates the context menus
	create_rmb_context_menus()
	
	# connecting signals
	connect('item_selected', self, '_on_item_selected')
	connect('item_rmb_selected', self, '_on_item_rmb_selected')
	connect('item_collapsed', self, '_on_item_collapsed')
	connect('gui_input', self, '_on_gui_input')
	connect('item_edited', self, '_on_item_edited')
	$RenamerReset.connect("timeout", self, '_on_renamer_reset_timeout')
	filter_tree_edit.connect("text_changed", self, '_on_filter_tree_edit_changed')
	
	
	# build all tree parts
	build_full_tree()
	
	# Default empty screen.
	hide_all_editors() 
	
	# AutoSave timer
	$AutoSave.connect("timeout", self, '_on_autosave_timeout')
	$AutoSave.start(0.5)

func _process(delta):
	if dragging_item != null:
		if Input.is_mouse_button_pressed(1):
			dragging_item.rect_global_position = get_global_mouse_position()+Vector2(10,10)
		else:
			dragging_item.queue_free()
			dragging_item = null

## *****************************************************************************
##						BUILDING THE TREE
## *****************************************************************************

func build_full_tree(selected_item: String = ''):
	# Adding timelines
	build_timelines(selected_item)
	# Adding characters
	build_characters(selected_item)
	# Adding Definitions
	build_definitions(selected_item)
	# Adding Themes
	build_themes(selected_item)

func _clear_tree_children(parent: TreeItem):
	while parent.get_children() != null:
		parent.get_children().free()

func _add_folder_item(parent_item: TreeItem, folder_name: String, editor:String, meta_folder_info:Dictionary):
	var folder_item:TreeItem= tree.create_item(parent_item)
	folder_item.set_text(0, folder_name)
	folder_item.set_icon(0, get_icon("Folder", "EditorIcons"))
	folder_item.set_icon_modulate(0, get_color("folder_icon_modulate", "FileDialog"))
	folder_item.set_metadata(0, {'editor': editor, 'editable': true})
	if filter_tree_term.empty():
		folder_item.collapsed = meta_folder_info['folded']
	return folder_item

## TIMELINES
func build_resource_folder(parent_folder_item:TreeItem, folder_data:Dictionary, selected_item:String, folder_editor:String, resource_type: String):
	for folder in folder_data["folders"].keys():
		var folder_item = _add_folder_item(parent_folder_item, folder, folder_editor, folder_data["folders"][folder]['metadata'])
		var contains_something = build_resource_folder(folder_item, folder_data["folders"][folder], selected_item, folder_editor, resource_type)
		if (not filter_tree_term.empty()) and (not contains_something):
			folder_item.free()
	for file in folder_data["files"]:
		match resource_type:
			"Timeline":
				var file_metadata = DialogicUtil.get_timeline_dict()[file]
				if (filter_tree_term == '') or (filter_tree_term.to_lower() in file_metadata['name'].to_lower()):
					_add_timeline(parent_folder_item, file_metadata, not selected_item.empty() and file == selected_item)
			"Character":
				var file_metadata = DialogicUtil.get_characters_dict()[file]
				if (filter_tree_term == '') or (filter_tree_term.to_lower() in file_metadata['name'].to_lower()):
					_add_character(parent_folder_item, file_metadata ,not selected_item.empty() and file == selected_item)
			"Theme":
				var file_metadata = DialogicUtil.get_theme_dict()[file]
				if (filter_tree_term == '') or (filter_tree_term.to_lower() in file_metadata['name'].to_lower()):
					_add_theme(parent_folder_item, file_metadata ,not selected_item.empty() and file == selected_item)
			"Definition":
				var file_metadata = DialogicUtil.get_default_definitions_dict()[file]
				if (filter_tree_term == '') or (filter_tree_term.to_lower() in file_metadata['name'].to_lower()):
					_add_definition(parent_folder_item, file_metadata ,not selected_item.empty() and file == selected_item)
	
	# force redraw control
	update()
	
	return true if (parent_folder_item.get_children() != null) else false

func build_timelines(selected_item: String=''):
	_clear_tree_children(timelines_tree)
	
	DialogicUtil.update_resource_folder_structure()
	var structure = DialogicUtil.get_timelines_folder_structure()
	build_resource_folder(timelines_tree, structure, selected_item, "Timeline Root", "Timeline")

func _add_timeline(parent_item, timeline_data, select = false):
	var item = tree.create_item(parent_item)
	item.set_icon(0, timeline_icon)
	if timeline_data.has('name'):
		item.set_text(0, timeline_data['name'])
	else:
		item.set_text(0, timeline_data['file'])
	timeline_data['editor'] = 'Timeline'
	timeline_data['editable'] = true
	item.set_metadata(0, timeline_data)
	if not get_constant("dark_theme", "Editor"):
		item.set_icon_modulate(0, get_color("property_color", "Editor"))
	#item.set_editable(0, true)
	if select: # Auto selecting
		item.select(0)


## CHARACTERS
func build_characters(selected_item: String=''):
	_clear_tree_children(characters_tree)
	
	DialogicUtil.update_resource_folder_structure()
	var structure = DialogicUtil.get_characters_folder_structure()
	build_resource_folder(characters_tree, structure, selected_item, "Character Root", "Character")

func _add_character(parent_item, character_data, select = false):
	var item = tree.create_item(parent_item)
	item.set_icon(0, character_icon)
	if character_data.has('name'):
		item.set_text(0, character_data['name'])
	else:
		item.set_text(0, character_data['file'])
	character_data['editor'] = 'Character'
	character_data['editable'] = true
	item.set_metadata(0, character_data)
	#item.set_editable(0, true)
	if character_data.has('color'):
		item.set_icon_modulate(0, character_data['color'])
	# Auto selecting
	if select: 
		item.select(0)


## DEFINTIONS
func build_definitions(selected_item: String=''):
	_clear_tree_children(definitions_tree)
	
	DialogicUtil.update_resource_folder_structure()
	var structure = DialogicUtil.get_definitions_folder_structure()
	build_resource_folder(definitions_tree, structure, selected_item, "Definition Root", "Definition")
	

func _add_definition(parent_folder_item, definition_data, select = false):
	var item = tree.create_item(parent_folder_item)
	item.set_text(0, definition_data['name'])
	item.set_icon(0, definition_icon)
	if definition_data['type'] == 1:
		item.set_icon(0, glossary_icon)
	definition_data['editor'] = 'Definition'
	definition_data['editable'] = true
	item.set_metadata(0, definition_data)
	if not get_constant("dark_theme", "Editor"):
		item.set_icon_modulate(0, get_color("property_color", "Editor"))
	if select: # Auto selecting
		item.select(0)


## THEMES
func build_themes(selected_item: String=''):
	_clear_tree_children(themes_tree)
	
	DialogicUtil.update_resource_folder_structure()
	var structure = DialogicUtil.get_theme_folder_structure()
	build_resource_folder(themes_tree, structure, selected_item, "Theme Root", "Theme")

func _add_theme(parent_folder_item, theme_data, select = false):
	var item = tree.create_item(parent_folder_item)
	item.set_icon(0, theme_icon)
	item.set_text(0, theme_data['name'])
	theme_data['editor'] = 'Theme'
	theme_data['editable'] = true
	item.set_metadata(0, theme_data)
	if not get_constant("dark_theme", "Editor"):
		item.set_icon_modulate(0, get_color("property_color", "Editor"))
	if select: # Auto selecting
		item.select(0)

func _on_item_collapsed(item: TreeItem):
	if filter_tree_term.empty() and item != null and 'Root' in item.get_metadata(0)['editor']:
		DialogicUtil.set_folder_meta(get_item_folder(item, ''), 'folded', item.collapsed)

## *****************************************************************************
##						 OPENING EDITORS
## *****************************************************************************

func _on_item_selected():
	# TODO: Ideally I would perform a "save" here before opening the next
	#       resource. Unfortunately there has been so many bugs doing that 
	#       that I'll revisit it in the future. 
	#       save_current_resource()
	var item = get_selected()
	var metadata = item.get_metadata(0)
	if metadata['editor'] == 'Timeline':
		timeline_editor.load_timeline(metadata['file'])
		show_timeline_editor()
	elif metadata['editor'] == 'Character':
		if not character_editor.is_selected(metadata['file']):
			character_editor.load_character(metadata['file'])
		show_character_editor()
	elif metadata['editor'] == 'Definition':
		if not definition_editor.is_selected(metadata['id']):
			definition_editor.visible = true
			definition_editor.load_definition(metadata['id'])
		show_definition_editor()
	elif metadata['editor'] == 'Theme':
		theme_editor.load_theme(metadata['file'])
		show_theme_editor()
	elif metadata['editor'] == 'Settings':
		settings_editor.update_data()
		show_settings_editor()
	else:
		hide_all_editors()

func show_timeline_editor():
	emit_signal("editor_selected", 'timeline')
	hide_editors()
	timeline_editor.visible = true

func show_character_editor():
	emit_signal("editor_selected", 'character')
	hide_editors()
	character_editor.visible = true

func show_definition_editor():
	emit_signal("editor_selected", 'definition')
	hide_editors()
	definition_editor.visible = true

func show_theme_editor():
	emit_signal("editor_selected", 'theme')
	hide_editors()
	theme_editor.visible = true

func show_settings_editor():
	emit_signal("editor_selected", 'theme')
	hide_editors()
	settings_editor.visible = true

func hide_all_editors():
	emit_signal("editor_selected", 'none')
	hide_editors()
	empty_editor.visible = true

func hide_editors():
	character_editor.visible = false
	timeline_editor.visible = false
	definition_editor.visible = false
	theme_editor.visible = false
	settings_editor.visible = false
	empty_editor.visible = false

## *****************************************************************************
##					 CONTEXT POPUPS on RMB SELECT
## *****************************************************************************

func create_rmb_context_menus():
	var timeline_popup = PopupMenu.new()
	timeline_popup.add_icon_item(get_icon("Filesystem", "EditorIcons"), 'Show in File Manager')
	timeline_popup.add_icon_item(get_icon("ActionCopy", "EditorIcons"), 'Copy Timeline Name')
	timeline_popup.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Timeline')
	add_child(timeline_popup)
	rmb_popup_menus["Timeline"] = timeline_popup
	
	var character_popup = PopupMenu.new()
	character_popup.add_icon_item(get_icon("Filesystem", "EditorIcons"), 'Show in File Manager')
	character_popup.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Character')
	add_child(character_popup)
	rmb_popup_menus["Character"] = character_popup
	
	var theme_popup = PopupMenu.new()
	theme_popup.add_icon_item(get_icon("Filesystem", "EditorIcons"), 'Show in File Manager')
	theme_popup.add_icon_item(get_icon("Duplicate", "EditorIcons"), 'Duplicate Theme')
	theme_popup.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Theme')
	add_child(theme_popup)
	rmb_popup_menus["Theme"] = theme_popup
	
	var definition_popup = PopupMenu.new()
	definition_popup.add_icon_item(get_icon("Edit", "EditorIcons"), 'Edit Definitions File')
	definition_popup.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Definition')
	add_child(definition_popup)
	rmb_popup_menus["Definition"] = definition_popup
	
	## FOLDER / ROOT ITEMS
	var timeline_folder_popup = PopupMenu.new()
	timeline_folder_popup.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Timeline')
	timeline_folder_popup.add_icon_item(get_icon("Folder", "EditorIcons") ,'Create Subfolder')
	timeline_folder_popup.add_icon_item(get_icon("Remove", "EditorIcons") ,'Delete Folder')
	add_child(timeline_folder_popup)
	rmb_popup_menus['Timeline Root'] = timeline_folder_popup
	
	var character_folder_popup = PopupMenu.new()
	character_folder_popup.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Character')
	character_folder_popup.add_icon_item(get_icon("Folder", "EditorIcons") ,'Create Subfolder')
	character_folder_popup.add_icon_item(get_icon("Remove", "EditorIcons") ,'Delete Folder')
	add_child(character_folder_popup)
	rmb_popup_menus['Character Root'] = character_folder_popup
	
	var theme_folder_popup = PopupMenu.new()
	theme_folder_popup.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Theme')
	theme_folder_popup.add_icon_item(get_icon("Folder", "EditorIcons") ,'Create Subfolder')
	theme_folder_popup.add_icon_item(get_icon("Remove", "EditorIcons") ,'Delete Folder')
	add_child(theme_folder_popup)
	rmb_popup_menus["Theme Root"] = theme_folder_popup
	
	var definition_folder_popup = PopupMenu.new()
	definition_folder_popup.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Definition')
	definition_folder_popup.add_icon_item(get_icon("Folder", "EditorIcons") ,'Create Subfolder')
	definition_folder_popup.add_icon_item(get_icon("Remove", "EditorIcons") ,'Delete Folder')
	add_child(definition_folder_popup)
	rmb_popup_menus["Definition Root"] = definition_folder_popup
	
	
	# Connecting context menus
	timeline_popup.connect('id_pressed', self, '_on_TimelinePopupMenu_id_pressed')
	character_popup.connect('id_pressed', self, '_on_CharacterPopupMenu_id_pressed')
	theme_popup.connect('id_pressed', self, '_on_ThemePopupMenu_id_pressed')
	definition_popup.connect('id_pressed', self, '_on_DefinitionPopupMenu_id_pressed')
	
	timeline_folder_popup.connect('id_pressed', self, '_on_TimelineRootPopupMenu_id_pressed')
	character_folder_popup.connect('id_pressed', self, '_on_CharacterRootPopupMenu_id_pressed')
	theme_folder_popup.connect('id_pressed', self, '_on_ThemeRootPopupMenu_id_pressed')
	definition_folder_popup.connect('id_pressed', self, '_on_DefinitionRootPopupMenu_id_pressed')

func _on_item_rmb_selected(position):
	var item = get_selected().get_metadata(0)
	if item.has('editor'):
		rmb_popup_menus[item["editor"]].rect_position = get_viewport().get_mouse_position()
		rmb_popup_menus[item["editor"]].popup()

## item paths (for the folder structure management)
# this returns the folder path, or the folder the item is in (if it's not a folder)
# it makes sure the folder_path begins with @root!
func get_item_folder(item: TreeItem, root : String):
	if not item:
		return root
	var current_path:String = get_item_path(item)
	if not "Root" in item.get_metadata(0)['editor']:
		current_path = DialogicUtil.get_parent_path(current_path)
	if not current_path.begins_with(root):
		return root
	return current_path
	
func get_item_path(item: TreeItem) -> String:
	if item == null:
		return ''
	return create_item_path_recursive(item, "").trim_suffix("/")

func create_item_path_recursive(item:TreeItem, path:String) -> String:
	# don't use this function directly
	# use get_item_path() or get_item_folder()
	path = item.get_text(0)+'/'+path
	if item.get_parent() == get_root():
		return path
	else:
		path = create_item_path_recursive(item.get_parent(), path)
	return path

## RESOURCE POPUPS

# Timeline context menu
func _on_TimelinePopupMenu_id_pressed(id):
	if id == 0: # View files
		OS.shell_open(ProjectSettings.globalize_path(DialogicResources.get_path('TIMELINE_DIR')))
	if id == 1: # Copy to clipboard
		OS.set_clipboard(editor_reference.get_node("MainPanel/TimelineEditor").timeline_name)
	if id == 2: # Remove
		editor_reference.get_node('RemoveTimelineConfirmation').popup_centered()

# Character context menu
func _on_CharacterPopupMenu_id_pressed(id):
	if id == 0:
		OS.shell_open(ProjectSettings.globalize_path(DialogicResources.get_path('CHAR_DIR')))
	if id == 1:
		editor_reference.get_node('RemoveCharacterConfirmation').popup_centered()

# Theme context menu
func _on_ThemePopupMenu_id_pressed(id):
	if id == 0:
		OS.shell_open(ProjectSettings.globalize_path(DialogicResources.get_path('THEME_DIR')))
	if id == 1:
		var filename = editor_reference.get_node('MainPanel/MasterTreeContainer/MasterTree').get_selected().get_metadata(0)['file']
		if (filename.begins_with('theme-')):
			editor_reference.theme_editor.duplicate_theme(filename)
	if id == 2:
		editor_reference.get_node('RemoveThemeConfirmation').popup_centered()

# Definition context menu
func _on_DefinitionPopupMenu_id_pressed(id):
	if id == 0:
		var paths = DialogicResources.get_config_files_paths()
		OS.shell_open(ProjectSettings.globalize_path(paths['DEFAULT_DEFINITIONS_FILE']))
	if id == 1:
		editor_reference.get_node('RemoveDefinitionConfirmation').popup_centered()

## FOLDER POPUPS

# Timeline Folder context menu
func _on_TimelineRootPopupMenu_id_pressed(id):
	if id == 0: # Add Timeline
		new_timeline()
	if id == 1: # add subfolder
		DialogicUtil.add_folder(get_item_path(get_selected()), "New Folder "+str(OS.get_unix_time()))
		build_timelines()
	if id == 2: # remove folder and substuff
		if get_selected().get_parent() == get_root():
			return
		editor_reference.get_node('RemoveFolderConfirmation').popup_centered()

# Character Folder context menu
func _on_CharacterRootPopupMenu_id_pressed(id):
	if id == 0: # Add Character
		new_character()
	if id == 1: # add subfolder
		DialogicUtil.add_folder(get_item_path(get_selected()), "New Folder "+str(OS.get_unix_time()))
		
		build_characters()
	if id == 2: # remove folder and substuff
		if get_selected().get_parent() == get_root():
			return
		editor_reference.get_node('RemoveFolderConfirmation').popup_centered()

# Definition Folder context menu
func _on_DefinitionRootPopupMenu_id_pressed(id):
	if id == 0: # Add Definition
		new_definition()
	if id == 1: # add subfolder
		DialogicUtil.add_folder(get_item_path(get_selected()), "New Folder "+str(OS.get_unix_time()))
		build_definitions()
	if id == 2: # remove folder and substuff
		if get_selected().get_parent() == get_root():
			return
		editor_reference.get_node('RemoveFolderConfirmation').popup_centered()

# Theme Folder context menu
func _on_ThemeRootPopupMenu_id_pressed(id):
	if id == 0: # Add Theme
		new_theme()
	if id == 1: # add subfolder
		DialogicUtil.add_folder(get_item_path(get_selected()), "New Folder "+str(OS.get_unix_time()))
		build_themes()
	if id == 2: # remove folder and substuff
		if get_selected().get_parent() == get_root():
			return
		editor_reference.get_node('RemoveFolderConfirmation').popup_centered()

## *****************************************************************************
##						 CREATING AND REMOVING
## *****************************************************************************

# creates a new timeline and opens it
# it will be added to the selected folder (if it's a timeline folder) or the Timeline root folder
func new_timeline():
	var timeline = editor_reference.get_node('MainPanel/TimelineEditor').create_timeline()
	var folder = get_item_folder(get_selected(), "Timelines")
	DialogicUtil.add_file_to_folder(folder, timeline['metadata']['file'])
	build_timelines(timeline['metadata']['file'])

# creates a new character and opens it
# it will be added to the selected folder (if it's a character folder) or the Character root folder
func new_character():
	var character = editor_reference.get_node("MainPanel/CharacterEditor").create_character()
	var folder = get_item_folder(get_selected(), "Characters")
	DialogicUtil.add_file_to_folder(folder, character['metadata']['file'])
	build_characters(character['metadata']['file'])

# creates a new theme and opens it
# it will be added to the selected folder (if it's a theme folder) or the Theme root folder
func new_theme():
	var theme_file = editor_reference.get_node("MainPanel/ThemeEditor").create_theme()
	var folder = get_item_folder(get_selected(), "Themes")
	DialogicUtil.add_file_to_folder(folder, theme_file)
	build_themes(theme_file)

# creates a new definition and opens it
# it will be added to the selected folder (if it's a definition folder) or the Definition root folder
func new_definition():
	var definition_id = editor_reference.get_node("MainPanel/DefinitionEditor").create_definition()
	var folder = get_item_folder(get_selected(), "Definitions")
	DialogicUtil.add_file_to_folder(folder, definition_id)
	build_definitions(definition_id)

func remove_selected():
	var item = get_selected()
	item.free()
	timelines_tree.select(0)
	settings_editor.update_data()


## *****************************************************************************
##					 		DRAGGING ITEMS
## *****************************************************************************

func can_drop_data(position, data) -> bool:
	var item = get_item_at_position(position)
	if item == null:
		return false
	# if the data isn't empty and it's a valid DICT
	if data != null and data is Dictionary and data.has('item_type'):
		# if it's not trying to add a folder to a file
		if not (data['item_type'] == "folder" and not 'Root' in item.get_metadata(0)["editor"]):
			# if it's the same type of folder as before
			if get_item_folder(item, '').split("/")[0] == data['orig_path'].split("/")[0]:
				# make sure the folder/item is not a subfolder of the original folder
				if data['item_type'] == "file" or (not get_item_folder(item, '').begins_with(data['orig_path'])):
					return true
	return false

func drop_data(position, data):
	var item = get_item_at_position(position)
	var drop_section = get_drop_section_at_position(position)
	if not data.has('item_type'):
		return
	if data['orig_path'] == get_item_folder(item, ''):
		return
	# dragging a folder
	if data['item_type'] == 'folder':
		# on a folder
		if 'Root' in item.get_metadata(0)['editor']:
			DialogicUtil.move_folder_to_folder(data['orig_path'], get_item_folder(item, data['orig_path'].split('/')[0]))
	# dragging a file
	elif data['item_type'] == 'file':
		# on a folder
		if 'Root' in item.get_metadata(0)['editor']:
			if data.has('file_name'):
				DialogicUtil.move_file_to_folder(data['file_name'], data['orig_path'], get_item_folder(item, data['orig_path'].split('/')[0]))
			elif data.has('resource_id'):
				DialogicUtil.move_file_to_folder(data['resource_id'], data['orig_path'], get_item_folder(item, data['orig_path'].split('/')[0]))
				pass # WORK TODO
		# on a file
		else:
			DialogicUtil.move_file_to_folder(data['file_name'], data['orig_path'], get_item_folder(item, data['orig_path'].split('/')[0]))
	dragging_item.queue_free()
	dragging_item = null
	build_full_tree()

func get_drag_data(position):
	var item = get_item_at_position(position)
	# if it is a folder and it's not one of the root folders
	if 'Root' in item.get_metadata(0)['editor'] and item.get_parent().get_parent():
		instance_drag_preview(item.get_icon(0), item.get_text(0))
		return {'item_type': 'folder', 'orig_path': get_item_folder(item, "")}
	else:
		if item.get_metadata(0).has('file'):
			instance_drag_preview(item.get_icon(0), item.get_text(0))
			return {'item_type': 'file', 'orig_path': get_item_folder(item, ""), 'file_name':item.get_metadata(0)['file']}
		elif item.get_metadata(0).has('id'):
			instance_drag_preview(item.get_icon(0), item.get_text(0))
			return {'item_type': 'file', 'orig_path': get_item_folder(item, ""), 'resource_id':item.get_metadata(0)['id']}
	return null

func instance_drag_preview(icon, text):
	dragging_item = drag_preview.instance()
	dragging_item.get_node("Panel").self_modulate = get_color("base_color", "Editor")
	dragging_item.get_node("Panel/HBox/Icon").texture = icon
	dragging_item.get_node("Panel/HBox/Label").text = text
	editor_reference.add_child(dragging_item)
	

## *****************************************************************************
##						 ITEM EDITING (RENAMING)
## *****************************************************************************

func _on_renamer_reset_timeout():
	get_selected().set_editable(0, false)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1:
		if event.is_pressed() and event.doubleclick:
			var item = get_selected()
			var metadata = item.get_metadata(0)
			if metadata.has("editable") and metadata["editable"]:
				item_path_before_edit = get_item_path(item)
				item.set_editable(0, true)
				$RenamerReset.start(0.5)

func _on_item_edited():
	var item = get_selected()
	var metadata = item.get_metadata(0)
	if metadata['editor'] == 'Timeline':
		timeline_editor.timeline_name = item.get_text(0)
		save_current_resource()
		build_timelines(metadata['file'])
	if metadata['editor'] == 'Theme':
		DialogicResources.set_theme_value(metadata['file'], 'settings', 'name', item.get_text(0))
		build_themes(metadata['file'])
	if metadata['editor'] == 'Character':
		character_editor.nodes['name'].text = item.get_text(0)
		save_current_resource()
		build_characters(metadata['file'])
	if metadata['editor'] == 'Definition':
		definition_editor.nodes['name'].text = item.get_text(0)
		# Not sure why this signal doesn't triggers
		definition_editor._on_name_changed(item.get_text(0))
		save_current_resource()
		build_definitions(metadata['id'])
	
	if "Root" in metadata['editor']:
		if item.get_text(0) == item_path_before_edit.split("/")[-1]:
			return 
		var result = DialogicUtil.rename_folder(item_path_before_edit, item.get_text(0))
		if result != OK:
			item.set_text(0, item_path_before_edit.split("/")[-1])
			
## *****************************************************************************
##					 		AUTO SAVING
## *****************************************************************************

func _on_autosave_timeout():
	save_current_resource()

func save_current_resource():
	var root = get_node('../..') # This is the same as the editor_reference
	if root.visible: #Only save if the editor is open
		var item: TreeItem = get_selected()
		var metadata: Dictionary
		if item != null:
			metadata = item.get_metadata(0)
			if metadata['editor'] == 'Timeline':
				timeline_editor.save_timeline()
			if metadata['editor'] == 'Character':
				character_editor.save_character()
			if metadata['editor'] == 'Definition':
				definition_editor.save_definition()
			# Note: Theme files auto saves on change


## *****************************************************************************
##					 	SEARCHING/FILTERING
## *****************************************************************************


func _on_filter_tree_edit_changed(value):
	filter_tree_term = value
	if not filter_tree_term.empty():
		timelines_tree.collapsed = false
		characters_tree.collapsed = false
		definitions_tree.collapsed = false
		themes_tree.collapsed = false
	else:
		timelines_tree.collapsed = DialogicUtil.get_folder_meta('Timelines', 'folded')
		characters_tree.collapsed = DialogicUtil.get_folder_meta('Timelines', 'folded')
		definitions_tree.collapsed = DialogicUtil.get_folder_meta('Timelines', 'folded')
		themes_tree.collapsed = DialogicUtil.get_folder_meta('Timelines', 'folded')
	
	if get_selected():
		build_full_tree(get_selected().get_metadata(0).get('file', ''))
	else:
		build_full_tree()


## *****************************************************************************
##					 	SELECTING AN ITEM
## *****************************************************************************

func select_timeline_item(timeline_name):
	if (timeline_name == ''):
		return

	var main_item = tree.get_root().get_children()
	
	# wow, godots tree traversal is extremly odd, or I just don't get it
	while (main_item):
		
		if (main_item == null):
			break
			
		if (main_item.has_method("get_text") && main_item.get_text(0) == "Timelines"):
			var item = main_item.get_children()
			while (item):
							
				if (not item.has_method("get_metadata")):
					item = item.get_next()
					continue
			
				var meta = item.get_metadata(0)
		
				if (meta == null):
					item = item.get_next()
					continue
		
				if (not meta.has("editor") or meta["editor"] != "Timeline"):
					item = item.get_next()
					continue
			
				# search for filename
				if (meta.has("file") and meta["file"] == timeline_name):
					# select this one
					item.select(0)
					return;
			
				# search for name
				if (meta.has("name") and meta["name"] == timeline_name):
					# select this one
					item.select(0)
					return;
	
				item = item.get_next()
			break
		else:
			main_item = main_item.get_next()
			
	# fallback
	hide_all_editors()
	pass

