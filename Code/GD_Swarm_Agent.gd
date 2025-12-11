# Authors: Michael Knighten & Matt Hensel 
# Class: CS7375 Artificial Intelligence, Section 01 
# Professor: Coskun Cetinkaya 
# Project Unsupervised Swarm Intelligence Exploration 

# Purpose: 
# - Utilizes swarm intelligence for navigation
# - Collects coins 
# - changes color on coin holding 
# - shares/appends data on trigger enter with Nest or other agent 
# - Records coordinates of unique tiles of interest

extends Node
class_name SwarmAgent

# --- Variables ------------------------------------

@export var Agent_Body: CharacterBody2D
@export var sensor: Area2D
@export var base_color: Color
@export var carrying_color: Color
@export var Agent_sprite: Sprite2D

# Movement tuning
@export var move_speed: float = 80.0
@export var wander_interval: float = 1.5
@export var wall_avoid_radius: float = 16.0

# Arrival thresholds (to avoid jitter at targets)
@export var nest_arrival_radius: float = 8.0
@export var coin_arrival_radius: float = 8.0

# How long to keep “pushing away” from a wall
@export var wall_avoid_min_time: float = 0.3
@export var wall_avoid_max_time: float = 1.0

# How far we must move away from the last wall
@export var wall_escape_radius: float = 32.0

# How long we force wandering after a wall hit while carrying a coin
@export var coin_wander_time: float = 1.0

# NEW: how strongly nest pulls the agent home (0 = no pull, 1 = pure beeline)
@export_range(0.0, 1.0, 0.05)
var home_bias: float = 0.6

# NEW: stuck detection
@export var stuck_distance_epsilon: float = 2.0        # how much movement counts as "moving"
@export var stuck_time_threshold: float = 1.5          # time (s) of low movement before we consider stuck
@export var stuck_wander_time: float = 10.0            # time (s) to force WANDER when stuck

var held_coins: int = 0
var nest: NestTile

# Local databank
var known_walls: Array[Vector2] = []
var known_goals: Array[Vector2] = []
var known_coins: Array[Vector2] = []

# Internal movement state
enum AgentState { WANDER, SEEK_COIN, RETURN_NEST }
var state: AgentState = AgentState.WANDER
var _velocity: Vector2 = Vector2.ZERO
var _decision_timer: float = 0.0

# Wall avoidance state
var _avoiding_wall: bool = false
var _avoid_timer: float = 0.0
var _avoid_duration: float = 0.0
var _avoid_dir: Vector2 = Vector2.ZERO

# Remember last wall that caused avoidance
var _last_wall_pos: Vector2 = Vector2.ZERO
var _has_last_wall: bool = false

# coin-wander flip-flop
var _force_coin_wander: bool = false
var _coin_wander_timer: float = 0.0

# NEW: stuck override
var _stuck_timer: float = 0.0
var _stuck_force_wander: bool = false
var _stuck_wander_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

# --- Godot Functions ------------------------------------

func _ready() -> void:
	if sensor:
		sensor.body_entered.connect(_on_trigger_enter)
	update_color_for_coins()
	if Agent_Body:
		_last_pos = Agent_Body.global_position

func _physics_process(delta: float) -> void:
	if Agent_Body == null:
		return

	_decision_timer += delta

	var pos := Agent_Body.global_position

	# --- STUCK DETECTION --------------------------------
	if _last_pos == Vector2.ZERO:
		_last_pos = pos

	var dist_moved := pos.distance_to(_last_pos)
	if dist_moved < stuck_distance_epsilon:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	# If we've been barely moving for long enough, trigger forced wander
	if _stuck_timer >= stuck_time_threshold and not _stuck_force_wander:
		_stuck_force_wander = true
		_stuck_wander_timer = stuck_wander_time
		_stuck_timer = 0.0
		print("SwarmAgent: STUCK detected, forcing wander for ", stuck_wander_time, " seconds")

	# Count down stuck-wander override
	if _stuck_force_wander:
		_stuck_wander_timer -= delta
		if _stuck_wander_timer <= 0.0:
			_stuck_force_wander = false
			print("SwarmAgent: STUCK wander override ended")

	# Update coin-wander timer
	if _force_coin_wander:
		_coin_wander_timer -= delta
		if _coin_wander_timer <= 0.0:
			_force_coin_wander = false

	var desired_dir := Vector2.ZERO

	# --- Hard override: currently escaping a wall ---
	if _avoiding_wall:
		_avoid_timer += delta
		if _avoid_timer >= _avoid_duration:
			_avoiding_wall = false
		else:
			desired_dir = _avoid_dir
	else:
		# --- State selection ---
		if _stuck_force_wander:
			# Highest priority: if we are stuck, just wander
			state = AgentState.WANDER
		elif held_coins > 0 and nest != null:
			# If we still need to wander after wall contact, or we're near last wall, stay in WANDER
			if _force_coin_wander or (_has_last_wall and pos.distance_to(_last_wall_pos) <= wall_escape_radius):
				state = AgentState.WANDER
			else:
				state = AgentState.RETURN_NEST
		elif known_coins.size() > 0:
			state = AgentState.SEEK_COIN
		else:
			state = AgentState.WANDER

		# base_dir = raw steering direction before we apply any bias
		var base_dir := Vector2.ZERO
		var apply_home_bias := false

		match state:
			AgentState.RETURN_NEST:
				# NOTE: behavior here is *wander + pull toward nest*, not hard beeline
				apply_home_bias = true

				# same wander logic as WANDER
				if _decision_timer >= wander_interval or _velocity == Vector2.ZERO:
					base_dir = _random_direction()
					_decision_timer = 0.0
				else:
					base_dir = _velocity.normalized()

				# if we're basically at nest and the coins have been dropped,
				# go back to exploration
				if nest != null:
					var dist_to_nest := pos.distance_to(nest.sensor.global_position)
					if dist_to_nest <= nest_arrival_radius and held_coins == 0:
						state = AgentState.WANDER
						_decision_timer = wander_interval

			AgentState.SEEK_COIN:
				var target_coin := _get_closest_point(known_coins, pos)
				var dist_to_coin := pos.distance_to(target_coin)

				if dist_to_coin <= coin_arrival_radius:
					_remove_point(known_coins, target_coin)
					state = AgentState.WANDER
					_decision_timer = wander_interval
					base_dir = _random_direction()
				elif dist_to_coin > 0.001:
					base_dir = (target_coin - pos).normalized()

			AgentState.WANDER:
				if _decision_timer >= wander_interval or _velocity == Vector2.ZERO:
					base_dir = _random_direction()
					_decision_timer = 0.0
				else:
					base_dir = _velocity.normalized()

		if apply_home_bias and nest != null:
			var home_vec := nest.sensor.global_position - pos
			if home_vec.length() > 0.001:
				var home_dir := home_vec.normalized()
				# Blend wander direction and home direction
				desired_dir = (base_dir * (1.0 - home_bias) + home_dir * home_bias).normalized()
			else:
				desired_dir = base_dir.normalized()
		else:
			desired_dir = base_dir.normalized()

	# Apply movement
	_velocity = desired_dir * move_speed
	Agent_Body.velocity = _velocity
	Agent_Body.move_and_slide()

	# Update last position for next stuck check
	_last_pos = Agent_Body.global_position

# --- Holding coins ------------------------------------

func update_color_for_coins() -> void:
	Agent_sprite.modulate = carrying_color if held_coins > 0 else base_color

# --- Knowledge helpers ------------------------------------

func _add_unique(arr: Array[Vector2], coord: Vector2) -> void:
	for c in arr:
		if c == coord:
			return
	arr.append(coord)

func _remove_point(arr: Array[Vector2], coord: Vector2) -> void:
	var i := 0
	while i < arr.size():
		if arr[i].distance_squared_to(coord) < 0.01:
			arr.remove_at(i)
		else:
			i += 1

func record_wall(coord: Vector2) -> void:
	# DEBUG: verify walls are actually being recorded (this only prints on hit)
	print("SwarmAgent: record_wall at ", coord)
	_add_unique(known_walls, coord)
	print("SwarmAgent: known_walls count = ", known_walls.size())

func record_coin(coord: Vector2) -> void:
	_add_unique(known_coins, coord)

func record_goal(coord: Vector2) -> void:
	_add_unique(known_goals, coord)

func set_nest(nest_ref: NestTile) -> void:
	nest = nest_ref
	_add_unique(known_goals, nest.sensor.global_position)

# --- data sharing ------------------------------------

func _on_trigger_enter(body: Node) -> void:
	if not (body is SwarmAgent or body is NestTile):
		return
	_share_databanks(body)

func _share_databanks(other) -> void:
	if not (other is SwarmAgent or other is NestTile):
		return
		
	for data in other.known_walls:
		_add_unique(known_walls, data)
	for data in other.known_goals:
		_add_unique(known_goals, data)
	for data in other.known_coins:
		_add_unique(known_coins, data)

	for data in known_walls:
		other._add_unique(other.known_walls, data)
	for data in known_goals:
		other._add_unique(other.known_goals, data)
	for data in known_coins:
		other._add_unique(other.known_coins, data)

# --- Movement helpers ------------------------------------

func _random_direction() -> Vector2:
	var angle := randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle))

func _get_closest_point(points: Array[Vector2], origin: Vector2) -> Vector2:
	if points.is_empty():
		return origin

	var closest := points[0]
	var best_d2 := origin.distance_squared_to(closest)

	for p in points:
		var d2 := origin.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			closest = p

	return closest

func _is_near_known_wall(pos: Vector2) -> bool:
	for w in known_walls:
		if pos.distance_squared_to(w) <= wall_avoid_radius * wall_avoid_radius:
			return true
	return false

# --- Wall avoidance ------------------------------------

func start_wall_avoidance(wall_pos: Vector2) -> void:
	if Agent_Body == null:
		return

	var pos := Agent_Body.global_position

	_last_wall_pos = wall_pos
	_has_last_wall = true

	var dir_to_nest := Vector2.ZERO
	if held_coins > 0 and nest != null:
		dir_to_nest = (nest.sensor.global_position - pos).normalized()

	if dir_to_nest != Vector2.ZERO:
		var side := 1.0 if randf() < 0.5 else -1.0
		var tangent := Vector2(-dir_to_nest.y, dir_to_nest.x) * side
		_avoid_dir = tangent.normalized()
	else:
		var away := pos - wall_pos
		if away == Vector2.ZERO:
			away = _random_direction()
		var angle_jitter := randf_range(-PI / 4.0, PI / 4.0)
		_avoid_dir = away.normalized().rotated(angle_jitter)

	_avoid_duration = randf_range(wall_avoid_min_time, wall_avoid_max_time)
	_avoid_timer = 0.0
	_avoiding_wall = true
	_decision_timer = 0.0

	print("SwarmAgent: start_wall_avoidance from wall at ", wall_pos,
		" pos=", pos,
		" avoid_dir=", _avoid_dir,
		" duration=", _avoid_duration)

	if held_coins > 0:
		_force_coin_wander = true
		_coin_wander_timer = coin_wander_time
