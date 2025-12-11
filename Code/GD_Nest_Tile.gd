# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - Tracks tiles discovered
# - Detects total coins on grid at initialization for collection comparison
# - Tracks coins collected
# - Tracks time spent between initialization and coin collection completion
# - Enacts the end game state when criteria is met (INCOMPLETE)
# - Controls the swarm population spawn at initialization

extends Node
class_name NestTile

# --- Variables ------------------------------------
@export var Metrics_Output: Label
@export var Spawned_Agent: PackedScene
@export var spawn_radius: float = 1.0
@export var sensor: Area2D
@export var initial_agent_population: int = 1  # how many to spawn at start

var total_coin_target: int

# Metrics
var agents_spawned: int = 0                  # runtime counter
var tiles_found: int = 0
var held_coins: int = 0                      # COINS IN NEST
var stopwatch: float = 0.0
var timer_running: bool = true
var known_walls: Array[Vector2] = []
var known_goals: Array[Vector2] = []
var known_coins: Array[Vector2] = []

# --- Godot Functions ------------------------------------

func _ready() -> void:
	auto_detect_total_coins()
	_add_unique(known_goals, sensor.global_position)
	_update_tiles_found()
	# detect agents entering the nest
	if sensor:
		sensor.body_entered.connect(_on_nest_sensor_enter)
	# Spawn initial population
	_spawn_agents(initial_agent_population)

func _process(delta: float) -> void:
	if timer_running:
		stopwatch += delta
		if held_coins >= total_coin_target:
			timer_running = false
			_on_all_coins_collected()
		display_metrics()

# --- End Game State ------------------------------------

func _on_all_coins_collected() -> void:
	get_tree().paused = true

# --- Metrics Output ------------------------------------

func display_metrics() -> void:
	Metrics_Output.text = "Time (seconds): %.2f" % stopwatch \
	+ "\nAgents spawned: " + str(agents_spawned) \
	+ "\nTiles found: " + str(tiles_found) \
	+ "\nCoins in nest: " + str(held_coins) \
	+ "\nTotal coins target: " + str(total_coin_target)

# --- Agent Spawner ------------------------------------

func _spawn_agents(count: int) -> void:
	for i in range(count):
		spawn_agent()

func spawn_agent() -> void:
	var agent_root := Spawned_Agent.instantiate()
	if agent_root == null:
		return

	add_child(agent_root)

	var agent_script := agent_root.get_node("Code_Container/GD_Swarm_Agent") as SwarmAgent
	if agent_script == null:
		push_warning("spawn_agent: Could not find SwarmAgent at Code_Container/GD_Swarm_Agent")
	else:
		agent_script.set_nest(self)

	var offset := Vector2(
		randf_range(-spawn_radius, spawn_radius),
		randf_range(-spawn_radius, spawn_radius)
	)

	agent_root.global_position = sensor.global_position + offset
	agents_spawned += 1

# --- Nest sensor: receive coins & data from agents -----

func _on_nest_sensor_enter(body: Node) -> void:
	# only react to agent roots
	if not body.is_in_group("Agents"):
		return

	var agent_script := body.get_node("Code_Container/GD_Swarm_Agent") as SwarmAgent
	if agent_script == null:
		push_warning("NestTile: Could not find SwarmAgent at Code_Container/GD_Swarm_Agent on %s" % body.name)
		return

	_share_databanks(agent_script)  # this will also transfer coins & change color

# --- Detect total Coins on Map -------------------------------------------------------

func auto_detect_total_coins() -> void:
	total_coin_target = 0

	for node in get_tree().get_nodes_in_group("Coins"):
		if node.is_inside_tree():
			total_coin_target += 1

	for node in get_tree().get_nodes_in_group("Goals"):
		if node.is_inside_tree():
			total_coin_target += 2

	print("Detected total coins on map: ", total_coin_target)

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

func _share_databanks(other: SwarmAgent) -> void:
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

	# Transfer coins from agent to nest
	if other.held_coins > 0:
		held_coins += other.held_coins
		other.held_coins = 0
		other.update_color_for_coins()
		print("Nest now holds ", held_coins, " / ", total_coin_target, " coins")
