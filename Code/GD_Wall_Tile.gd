# Authors: Michael Knighten & Matt Hensel
# Class: CS7375 Artificial Intelligence, Section 01
# Professor: Coskun Cetinkaya
# Project Unsupervised Swarm Intelligence Exploration

# Purpose:
# - A standard boundary obstacle
# - shares self coordinate data with agents

extends Node
class_name WallTile

# --- Variables ------------------------------------

@export var sensor: Area2D

# --- Godot Functions ------------------------------------

func _ready() -> void:
	sensor.body_entered.connect(_on_trigger_enter)

# --- data sharing ------------------------------------

func _on_trigger_enter(body: Node) -> void:
	if body is SwarmAgent:
		var agent := body as SwarmAgent
		agent.record_wall(sensor.global_position)
