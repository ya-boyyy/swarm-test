# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - grants 1 coin to an agent
# - Hides when triggered

extends Node
class_name CoinTile

# --- Variables ------------------------------------

@export var sensor: Area2D
@export var sprite: Sprite2D

# --- Godot Functions ------------------------------------

func _ready() -> void:
	sensor.body_entered.connect(_on_trigger_enter)

# --- Coin Operations ------------------------------------

func _on_trigger_enter(body: Node) -> void:
	if not body is SwarmAgent:
		return
	var agent := body as SwarmAgent
	agent.held_coins += 1
	agent.update_color_for_coins()
	agent.record_coin(sensor.global_position)
	sprite.visible = false
	sensor.hide()
	set_deferred("monitoring", false)
