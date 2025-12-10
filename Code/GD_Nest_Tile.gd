# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - Tracks tiles discovered
# - Detects total coins on grid at initialization for collection comparison (INCOMPLETE)
# - Tracks coins collected
# - Tracks time spent between initialization and coin collection completion
# - Enacts the end game state when criteria is met (INCOMPLETE)
# - Controls the swarm population spawn at initialization (INCOMPLETE)

extends Node
class_name NestTile

# --- Variables ------------------------------------

@export var sensor: Area2D
var total_coin_target: int # should autodetect coins on map************

# Metrics
var agent_population_spawned: int = 0
var tiles_found: int = 0
var held_coins: int = 0
var stopwatch: float = 0.0
var timer_running: bool = true
var known_walls: Array[Vector2] = []
var known_goals: Array[Vector2] = []
var known_coins: Array[Vector2] = []

# --- Godot Functions ------------------------------------

func _ready() -> void:
	_add_unique(known_goals, sensor.global_position)
	_update_tiles_found()


func _process(delta: float) -> void:
	if timer_running:
		stopwatch += delta
		if held_coins >= total_coin_target:
			timer_running = false
			_on_all_coins_collected()

# --- Nest Functions ------------------------------------

func _on_all_coins_collected() -> void:
	print("All coins collected!")
	print("Time (seconds): ", stopwatch)
	print("Agents spawned: ", agent_population_spawned)
	print("Tiles found: ", tiles_found)
	# Here you can emit a signal or call game over.*********************


# --- Knowledge handling -------------------------------------------------------

func _add_unique(array: Array[Vector2], coord: Vector2) -> void:
	for c in array:
		if c == coord:
			return
	array.append(coord)


func record_wall(coord: Vector2) -> void:
	_add_unique(known_walls, coord)
	_update_tiles_found()


func record_coin(coord: Vector2) -> void:
	_add_unique(known_coins, coord)
	_update_tiles_found()


func record_goal(coord: Vector2) -> void:
	_add_unique(known_goals, coord)
	_update_tiles_found()


func _update_tiles_found() -> void:
	# distinct positions across all arrays
	var tmp: Array[Vector2] = []
	for a in [known_walls, known_goals, known_coins]:
		for c in a:
			var exists := false
			for t in tmp:
				if t == c:
					exists = true
					break
			if not exists:
				tmp.append(c)
	tiles_found = tmp.size()


func _share_databanks(other) -> void:
	if not (other is SwarmAgent):
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

	# Transfer coins if agent is carrying
	if other.held_coins > 0:
		held_coins += other.held_coins
		other.held_coins = 0
		other.update_color_for_coins()
		print("Nest now holds ", held_coins, " / ", total_coin_target, " coins")
