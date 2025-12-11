# Authors: Michael Knighten & Matt Hensel 
# Class: CS7375 Artificial Intelligence, Section 01 
# Professor: Coskun Cetinkaya 
# Project Unsupervised Swarm Intelligence Exploration 

# Purpose: 
# - A standard boundary obstacle
# - shares self coordinate data with agents

extends Node
class_name WallTile

@export var sensor: Area2D

func _ready() -> void:
	if sensor:
		sensor.body_entered.connect(_on_trigger_enter)

func _on_trigger_enter(body: Node) -> void:
	# Only react to agent roots (CharacterBody2D in "Agents" group)
	if not body.is_in_group("Agents"):
		return

	print("WallTile: AGENT hit wall! body = ", body.name, " at ", sensor.global_position)

	var agent_script := body.get_node("Code_Container/GD_Swarm_Agent") as SwarmAgent
	if agent_script == null:
		push_warning("WallTile: Could not find SwarmAgent at Code_Container/GD_Swarm_Agent on %s" % body.name)
		return

	agent_script.record_wall(sensor.global_position)
	agent_script.start_wall_avoidance(sensor.global_position)
