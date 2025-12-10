# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - Utilizes swarm intelligence for navigation (INCOMPLETE)
# - Collects coins
# - changes color on coin holding
# - shares/appends data on trigger enter with Nest or other agent
# - Records coordinates of unique tiles of interest

extends Node
class_name SwarmAgent

# --- Variables ------------------------------------

@export var nest: NestTile
@export var Agent_Body: CharacterBody2D
@export var sensor: Area2D
@export var base_color: Color
@export var carrying_color: Color
@export var Agent_sprite: Sprite2D

var held_coins: int = 0

# Local databank
var known_walls: Array[Vector2] = []
var known_goals: Array[Vector2] = []
var known_coins: Array[Vector2] = []

# --- Godot Functions ------------------------------------

func _ready() -> void:
	if nest:
		# Free knowledge: nest position
		_add_unique(known_goals, nest.global_position)

	if sensor:
		sensor.body_entered.connect(_on_trigger_enter)
	
	update_color_for_coins()

func _physics_process(delta: float) -> void:
	# Movement/swarm behavior goes here later—right now we just care about data flow.*******************
	pass

# --- Holding coins ------------------------------------

func update_color_for_coins() -> void:
	Agent_sprite.modulate = carrying_color if held_coins > 0 else base_color

# --- Knowledge helpers ------------------------------------

func _add_unique(arr: Array[Vector2], coord: Vector2) -> void:
	for c in arr:
		if c == coord:
			return
	arr.append(coord)

func record_wall(coord: Vector2) -> void:
	_add_unique(known_walls, coord)

func record_coin(coord: Vector2) -> void:
	_add_unique(known_coins, coord)

func record_goal(coord: Vector2) -> void:
	_add_unique(known_goals, coord)

# --- data sharing ------------------------------------

func _on_trigger_enter(body: Node) -> void:
	# Only react to SwarmAgent or NestTile
	if not (body is SwarmAgent or body is NestTile):
		return
		
	_share_databanks(body)

func _share_databanks(other) -> void:
	if not (other is SwarmAgent or other is NestTile):
		return  # ignore anything else
		
	# Take data:
	for data in other.known_walls:
		_add_unique(known_walls, data)
	for data in other.known_goals:
		_add_unique(known_goals, data)
	for data in other.known_coins:
		_add_unique(known_coins, data)
		
	# Give data:
	for data in known_walls:
		other._add_unique(other.known_walls, data)
	for data in known_goals:
		other._add_unique(other.known_goals, data)
	for data in known_coins:
		other._add_unique(other.known_coins, data)
