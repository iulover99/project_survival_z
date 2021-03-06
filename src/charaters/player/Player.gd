class_name Player
extends KinematicBody

const MIN_CAMERA_ANGLE = -60
const MAX_CAMERA_ANGLE = 85
const FOV_DEFAULT = 70
const FOV_ADS = 55
const ADS_LERP = 30
const MAX_HEART = 100

var isCaptureMouse = true

export(Constants.Weapon) var selectedWeapon
var previousWeapon = Constants.Weapon.NONE
var currentWeapon = Constants.Weapon.NONE
onready var groundCheck = $GroundCheck

export(int, 0, 100) var currentHeart:int

export(Vector3) var default_gun_position
export(Vector3) var ads_gun_position

export(float, 0, 1, 0.05) var camera_sensitivity = 0.05

export(float, 0, 15, 0.1) var gravity := 9.8
export(float, 0, 100, 0.5) var speed := 10.0
export(float, 0, 20, 0.1) var acceleration := 6.0
export(float, 0, 50, 0.5) var jump_impulse := 5.0

export(NodePath) onready var head = get_node(head) as Spatial
export(NodePath) onready var raycast = get_node(raycast) as RayCast
export(NodePath) onready var hand = get_node(hand) as Spatial
export(NodePath) onready var camera = get_node(camera) as Camera
export(NodePath) onready var gunViewPort = get_node(gunViewPort) as Viewport
export(NodePath) onready var gunCamera = get_node(gunCamera) as Camera
export(NodePath) onready var animationPlayer = get_node(animationPlayer) as AnimationPlayer
export(NodePath) onready var effectPlayer = get_node(effectPlayer) as AnimationPlayer
export (NodePath) onready var crossHairNode = get_node(crossHairNode) as TextureRect

var knifePickupSound: AudioStream = preload('res://assets/sounds/sfx/knife_pickup.wav')
var gunPickUpSound: AudioStream = preload('res://assets/sounds/sfx/gun_reload_sound.wav')
var healingSound: AudioStream = preload('res://assets/sounds/sfx/healing_sound_effect.wav')
var hurtSound: AudioStream = preload('res://assets/sounds/sfx/hurt_sound.wav')

#vectors
var velocity: Vector3 = Vector3.ZERO
var mouseDelta: Vector2 = Vector2.ZERO

func _ready():
	var error_code = GameEvents.connect('heart_decrease',self,"on_heart_decrease_handle")
	StaticHelper.log_error_code(error_code, self.name)
	error_code = GameEvents.connect('pick_up_item', self, "on_pick_up_item_handle")
	gunViewPort.size = get_viewport().size
	GameEvents.emit_signal('update_heart_ui', currentHeart)
	error_code = GameEvents.connect('push_charater', self, "on_charater_pushed_handle")
	
	GameEvents.emit_signal('update_ammo_ui',0,0)
	
func on_charater_pushed_handle(push_vector: Vector3):
	velocity.x = push_vector.x
	velocity.z = push_vector.z

func _input(event) -> void:
	_aim(event)
	
func _process(_delta: float) -> void:
	gunCamera.global_transform = camera.global_transform

func _on_ViewportContainer_resized() -> void:
	if gunViewPort is Viewport:
		gunViewPort.size = get_viewport().size

func _aim(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg2rad(-event.relative.x * camera_sensitivity))
		head.rotate_x(deg2rad(-event.relative.y * camera_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg2rad(Constants.MIN_CAMERA_ANGLE), deg2rad(Constants.MAX_CAMERA_ANGLE))

#index belong to Weapon Enum, but we can't pass enum here so we will pass int instead
func get_weapon_node(weaponType: int) -> Spatial:
	if weaponType >= Constants.Weapon.NONE:
		return null
	if hand.get_child(weaponType).get_child_count() > 0:
		return hand.get_child(weaponType).get_child(0)
	return null

func add_weapon(weaponType: int, weaponInstance: Spatial) -> void:
	hand.get_child(weaponType).add_child(weaponInstance)
	
func on_heart_decrease_handle(targetNode: Spatial, ammount: int) -> void:
	if targetNode != self:
		return
	GlobalSoundManager.play_sound(hurtSound, -5.0)
	effectPlayer.play("Pain")
	currentHeart = int(clamp(float(currentHeart - ammount), 0.0, 100.0))
	GameEvents.emit_signal('update_heart_ui', currentHeart)
	if currentHeart == 0:
		yield(effectPlayer,'animation_finished')
		GameEvents.emit_signal('level_finished', false)
	
func on_pick_up_item_handle(itemNode: Spatial ,itemType: int, playerNode: Spatial, weaponInstance: Spatial, weaponType: int) -> void:
	if itemType == Constants.ItemType.HEART:
		if currentHeart == 100:
			GameEvents.emit_signal('pick_up_response', itemNode, false)
			return
		GlobalSoundManager.play_sound(healingSound, -10.0)
		currentHeart = int(clamp(float(currentHeart + 30), 0.0, 100.0))
		GameEvents.emit_signal('update_heart_ui', currentHeart)
		GameEvents.emit_signal('pick_up_response', itemNode, true)
	elif itemType == Constants.ItemType.AMMO:
		var currentWeaponNode = get_weapon_node(currentWeapon)
		if currentWeaponNode == null:
			GameEvents.emit_signal('pick_up_response', itemNode, false)
			return
#		GameEvents.emit_signal('pick_up_response', itemNode, true)
		GameEvents.emit_signal('gun_add_ammo',get_weapon_node(currentWeapon), itemNode)
		
	elif itemType == Constants.ItemType.WEAPON:
		if currentWeapon != Constants.Weapon.NONE:
			var currentWeaponNode = get_weapon_node(currentWeapon)
			if (currentWeaponNode != null):
				currentWeaponNode.visible = false
		add_weapon(weaponType, weaponInstance)
		currentWeapon = weaponType

		if weaponType == Constants.Weapon.MELEE:
			GlobalSoundManager.play_sound(knifePickupSound)
		else:
			GlobalSoundManager.play_sound(gunPickUpSound)

		GameEvents.emit_signal('weapon_change_success', weaponInstance)
		GameEvents.emit_signal('pick_up_response', itemNode, true)
		
