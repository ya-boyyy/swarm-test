# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - grants a set number of coins to an agent
# - Hides when triggered

extends Node
class_name GoalTile

# --- Variables ------------------------------------

@export var sensor: Area2D
@export var sprite: Sprite2D
@export var coins_given: int

# --- Godot Functions ------------------------------------

func _ready() -> void:
	sensor.body_entered.connect(_on_trigger_enter)

# --- Goal Operations ------------------------------------

func _on_trigger_enter(body: Node) -> void:
	if not body is SwarmAgent:
		return
	var agent := body as SwarmAgent
	agent.record_goal(sensor.global_position)
	agent.held_coins += coins_given
	agent.update_color_for_coins()
	agent.record_coin(sensor.global_position)
	sprite.visible = false
	sensor.hide()
	set_deferred("monitoring", false)
