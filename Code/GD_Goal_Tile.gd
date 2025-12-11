# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - grants 2 coins to an agent
# - Hides when triggered

extends Node
class_name GoalTile

@export var sensor: Area2D
@export var sprite: Sprite2D

func _ready() -> void:
	if sensor:
		sensor.body_entered.connect(_on_trigger_enter)

func _on_trigger_enter(body: Node) -> void:
	# Only react to agent roots
	if not body.is_in_group("Agents"):
		return

	# body is the root "agent" node (CharacterBody2D)
	var agent_script := body.get_node("Code_Container/GD_Swarm_Agent") as SwarmAgent
	if agent_script == null:
		push_warning("GoalTile: Could not find SwarmAgent at Code_Container/GD_Swarm_Agent on %s" % body.name)
		return

	# Mark this as a goal tile
	agent_script.record_goal(sensor.global_position)

	# Give 2 coins
	agent_script.held_coins += 2
	agent_script.update_color_for_coins()
	agent_script.record_coin(sensor.global_position)

	# Hide this goal (if it's “consumed”)
	if sprite:
		sprite.visible = false
	if sensor:
		sensor.hide()
		sensor.set_deferred("monitoring", false)
