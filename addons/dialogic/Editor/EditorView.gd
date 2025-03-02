tool
extends Control

var debug_mode: bool = true # For printing info
var editor_file_dialog # EditorFileDialog
var file_picker_data: Dictionary = {'method': '', 'node': self}
var current_editor_view: String = 'Master'
var version_string: String 
onready var master_tree = $MainPanel/MasterTreeContainer/MasterTree
onready var timeline_editor = $MainPanel/TimelineEditor
onready var character_editor = $MainPanel/CharacterEditor
onready var definition_editor = $MainPanel/DefinitionEditor
onready var theme_editor = $MainPanel/ThemeEditor
onready var settings_editor = $MainPanel/SettingsEditor

# this is set when the plugins main-view is instanced in dialogic.gd
var editor_interface = null

func _ready():
	# Adding file dialog to get used by Events
	editor_file_dialog = EditorFileDialog.new()
	add_child(editor_file_dialog)

	# Setting references to this node
	timeline_editor.editor_reference = self
	character_editor.editor_reference = self
	definition_editor.editor_reference = self
	theme_editor.editor_reference = self

	master_tree.connect("editor_selected", self, 'on_master_tree_editor_selected')

	# Updating the folder structure
	DialogicUtil.update_resource_folder_structure()
	
	# Sizes
	# This part of the code is a bit terrible. But there is no better way
	# of doing this in Godot at the moment. I'm sorry.
	var separation = get_constant("separation", "BoxContainer")
	$MainPanel.margin_left = separation
	$MainPanel.margin_right = separation * -1
	$MainPanel.margin_bottom = separation * -1
	$MainPanel.margin_top = 38
	var modifier = ''
	var _scale = get_constant("inspector_margin", "Editor")
	_scale = _scale * 0.125
	if _scale == 1:
		$MainPanel.margin_top = 30
	if _scale == 1.25:
		modifier = '-1.25'
		$MainPanel.margin_top = 37
	if _scale == 1.5:
		modifier = '-1.25'
		$MainPanel.margin_top = 46
	if _scale == 1.75:
		modifier = '-1.25'
		$MainPanel.margin_top = 53
	if _scale == 2:
		$MainPanel.margin_top = 59
		modifier = '-2'
	$ToolBar/NewTimelineButton.icon = load("res://addons/dialogic/Images/Toolbar/add-timeline" + modifier + ".svg")
	$ToolBar/NewCharactersButton.icon = load("res://addons/dialogic/Images/Toolbar/add-character" + modifier + ".svg")
	$ToolBar/NewDefinitionButton.icon = load("res://addons/dialogic/Images/Toolbar/add-definition" + modifier + ".svg")
	$ToolBar/NewThemeButton.icon = load("res://addons/dialogic/Images/Toolbar/add-theme" + modifier + ".svg")
	
	var modulate_color = Color.white
	if not get_constant("dark_theme", "Editor"):
		modulate_color = get_color("property_color", "Editor")
	$ToolBar/NewTimelineButton.modulate = modulate_color
	$ToolBar/NewCharactersButton.modulate = modulate_color
	$ToolBar/NewDefinitionButton.modulate = modulate_color
	$ToolBar/NewThemeButton.modulate = modulate_color
	
	$ToolBar/FoldTools/ButtonFold.icon = get_icon("GuiTreeArrowRight", "EditorIcons")
	$ToolBar/FoldTools/ButtonUnfold.icon = get_icon("GuiTreeArrowDown", "EditorIcons")
	# Toolbar
	$ToolBar/NewTimelineButton.connect('pressed', $MainPanel/MasterTreeContainer/MasterTree, 'new_timeline')
	$ToolBar/NewCharactersButton.connect('pressed', $MainPanel/MasterTreeContainer/MasterTree, 'new_character')
	$ToolBar/NewThemeButton.connect('pressed', $MainPanel/MasterTreeContainer/MasterTree, 'new_theme')
	$ToolBar/NewDefinitionButton.connect('pressed', $MainPanel/MasterTreeContainer/MasterTree, 'new_definition')
	$ToolBar/Docs.icon = get_icon("Instance", "EditorIcons")
	$ToolBar/Docs.connect('pressed', OS, "shell_open", ["https://dialogic.coppolaemilio.com"])
	$ToolBar/FoldTools/ButtonFold.connect('pressed', timeline_editor, 'fold_all_nodes')
	$ToolBar/FoldTools/ButtonUnfold.connect('pressed', timeline_editor, 'unfold_all_nodes')
	
	
#	# Resetting the context menu items and size
#	var context_menus = [
#		$TimelinePopupMenu, $CharacterPopupMenu, $ThemePopupMenu,
#		$DefinitionPopupMenu, $TimelineRootPopupMenu, $CharacterRootPopupMenu,
#		$ThemeRootPopupMenu, $DefinitionRootPopupMenu]
#	for menu in context_menus:
#		menu.clear()
#		menu.rect_size = Vector2(0, 0)
	# Adding items to context menus
#
#	$TimelinePopupMenu.add_icon_item(get_icon("Filesystem", "EditorIcons"), 'Show in File Manager')
#	$TimelinePopupMenu.add_icon_item(get_icon("ActionCopy", "EditorIcons"), 'Copy Timeline Name')
#	$TimelinePopupMenu.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Timeline')
#
#	$CharacterPopupMenu.add_icon_item(get_icon("Filesystem", "EditorIcons"), 'Show in File Manager')
#	$CharacterPopupMenu.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Character')
#
#	$ThemePopupMenu.add_icon_item(get_icon("Filesystem", "EditorIcons"), 'Show in File Manager')
#	$ThemePopupMenu.add_icon_item(get_icon("Duplicate", "EditorIcons"), 'Duplicate Theme')
#	$ThemePopupMenu.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Theme')
#
#	$DefinitionPopupMenu.add_icon_item(get_icon("Edit", "EditorIcons"), 'Edit Definitions File')
#	$DefinitionPopupMenu.add_icon_item(get_icon("Remove", "EditorIcons"), 'Remove Definition')
#
#	$TimelineRootPopupMenu.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Timeline')
#	$CharacterRootPopupMenu.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Character')
#	$ThemeRootPopupMenu.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Theme')
#	$DefinitionRootPopupMenu.add_icon_item(get_icon("Add", "EditorIcons") ,'Add Definition')
#
#	# Connecting context menus
#	$TimelinePopupMenu.connect('id_pressed', self, '_on_TimelinePopupMenu_id_pressed')
#	$CharacterPopupMenu.connect('id_pressed', self, '_on_CharacterPopupMenu_id_pressed')
#	$ThemePopupMenu.connect('id_pressed', self, '_on_ThemePopupMenu_id_pressed')
#	$DefinitionPopupMenu.connect('id_pressed', self, '_on_DefinitionPopupMenu_id_pressed')
#	$TimelineRootPopupMenu.connect('id_pressed', self, '_on_TimelineRootPopupMenu_id_pressed')
#	$CharacterRootPopupMenu.connect('id_pressed', self, '_on_CharacterRootPopupMenu_id_pressed')
#	$ThemeRootPopupMenu.connect('id_pressed', self, '_on_ThemeRootPopupMenu_id_pressed')
#	$DefinitionRootPopupMenu.connect('id_pressed', self, '_on_DefinitionRootPopupMenu_id_pressed')
#
	#Connecting confirmation menus
	$RemoveTimelineConfirmation.connect('confirmed', self, '_on_RemoveTimelineConfirmation_confirmed')
	$RemoveFolderConfirmation.connect('confirmed', self, '_on_RemoveFolderConfirmation_confirmed')
	$RemoveCharacterConfirmation.connect('confirmed', self, '_on_RemoveCharacterConfirmation_confirmed')
	$RemoveThemeConfirmation.connect('confirmed', self, '_on_RemoveThemeConfirmation_confirmed')
	$RemoveDefinitionConfirmation.connect('confirmed', self, '_on_RemoveDefinitionConfirmation_confirmed')
	
	# Loading the version number
	var config = ConfigFile.new()
	var err = config.load("res://addons/dialogic/plugin.cfg")
	if err == OK:
		version_string = config.get_value("plugin", "version", "?")
		$ToolBar/Version.text = 'Dialogic v' + version_string
		
	$MainPanel/MasterTreeContainer/FilterMasterTreeEdit.right_icon = get_icon("Search", "EditorIcons")


func on_master_tree_editor_selected(editor: String):
	$ToolBar/FoldTools.visible = editor == 'timeline'



func _on_RemoveTimelineConfirmation_confirmed():
	var dir = Directory.new()
	var target = $MainPanel/TimelineEditor.timeline_file
	#'target: ', target)
	DialogicResources.delete_timeline(target)
	DialogicUtil.update_resource_folder_structure()
	$MainPanel/MasterTreeContainer/MasterTree.remove_selected()
	$MainPanel/MasterTreeContainer/MasterTree.hide_all_editors()


func _on_RemoveDefinitionConfirmation_confirmed():
	var target = $MainPanel/DefinitionEditor.current_definition['id']
	DialogicResources.delete_default_definition(target)
	$MainPanel/MasterTreeContainer/MasterTree.remove_selected()
	$MainPanel/MasterTreeContainer/MasterTree.hide_all_editors()

func _on_RemoveFolderConfirmation_confirmed():
	var item_path = $MainPanel/MasterTreeContainer/MasterTree.get_item_path($MainPanel/MasterTreeContainer/MasterTree.get_selected())
	DialogicUtil.remove_folder(item_path)
	$MainPanel/MasterTreeContainer/MasterTree.build_full_tree()

func _on_RemoveCharacterConfirmation_confirmed():
	var filename = $MainPanel/CharacterEditor.opened_character_data['id']
	DialogicResources.delete_character(filename)
	$MainPanel/MasterTreeContainer/MasterTree.remove_selected()
	$MainPanel/MasterTreeContainer/MasterTree.hide_all_editors()


func _on_RemoveThemeConfirmation_confirmed():
	var filename = $MainPanel/MasterTreeContainer/MasterTree.get_selected().get_metadata(0)['file']
	DialogicResources.delete_theme(filename)
	$MainPanel/MasterTreeContainer/MasterTree.remove_selected()
	$MainPanel/MasterTreeContainer/MasterTree.hide_all_editors()


# Godot dialog
func godot_dialog(filter, mode = EditorFileDialog.MODE_OPEN_FILE):
	editor_file_dialog.mode = mode
	editor_file_dialog.clear_filters()
	editor_file_dialog.popup_centered_ratio(0.75)
	editor_file_dialog.add_filter(filter)
	return editor_file_dialog


func godot_dialog_connect(who, method_name, signal_name = "file_selected"):
	# Checking if previous connection exists, if it does, disconnect it.
	if editor_file_dialog.is_connected(
		signal_name,
		file_picker_data['node'],
		file_picker_data['method']):
			editor_file_dialog.disconnect(
				signal_name,
				file_picker_data['node'],
				file_picker_data['method']
			)
	# Connect new signal
	editor_file_dialog.connect(signal_name, who, method_name, [who])
	file_picker_data['method'] = method_name
	file_picker_data['node'] = who


func _on_file_selected(path):
	dprint('[D] Selected '+str(path))


func dprint(what) -> void:
	if debug_mode:
		print(what)
