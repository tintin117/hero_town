extends Control

signal build_requested(building_type: String)
signal popup_hidden

const BuildingItemScene := preload("res://scenes/UI_building_item.tscn")

@onready var title_label: Label = $VBoxContainer/LabelControl/Label
@onready var option_list: GridContainer = $VBoxContainer/SelectionGrid/ScrollContainer/GridContainer
@onready var close_btn: TextureButton = $CloseButton/Close

## building id -> rendered thumbnail, so each model renders at most once.
var _thumb_cache: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(hide_popup)
	visible = false

# options: Array of {type, label, cost, can_afford, thumbnail, model_scene}
func show_options(options: Array) -> void:
	title_label.text = "Choose Building"

	for child in option_list.get_children():
		child.queue_free()

	for opt in options:
		var row := BuildingItemScene.instantiate() as BuildingItem
		option_list.add_child(row)
		row.setup(opt["thumbnail"], opt["label"], opt["cost"], opt["can_afford"])
		if opt["can_afford"]:
			var t: String = opt["type"]
			row.pressed.connect(func(): _on_option_pressed(t))
		if opt["thumbnail"] == null and opt.get("model_scene") != null:
			_apply_model_thumbnail(row, opt["type"], opt["model_scene"])

	visible = true

## Renders the building's 3D model into a small texture for the shop card.
func _apply_model_thumbnail(row: BuildingItem, building_id: String, model_scene: PackedScene) -> void:
	if _thumb_cache.has(building_id):
		row.building_image.texture = _thumb_cache[building_id]
		return
	var texture: Texture2D = await _render_thumbnail(model_scene)
	_thumb_cache[building_id] = texture
	if is_instance_valid(row):
		row.building_image.texture = texture

func _render_thumbnail(model_scene: PackedScene) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(model_scene.instantiate())
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0.95, 0.9, 1.4)
	camera.look_at(Vector3(0, 0.42, 0))
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return ImageTexture.create_from_image(image)

func hide_popup() -> void:
	visible = false
	popup_hidden.emit()

func _on_option_pressed(building_type: String) -> void:
	sfx.play("click")
	build_requested.emit(building_type)
	hide_popup()
