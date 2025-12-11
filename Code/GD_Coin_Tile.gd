extends Node
class_name CoinTile

@export var sensor: Area2D
@export var sprite: Sprite2D

func _ready() -> void:
	if sensor:
		sensor.body_entered.connect(_on_trigger_enter)

func _on_trigger_enter(body: Node) -> void:
	# Only react to agent roots
	if not body.is_in_group("Agents"):
		print("apples...")
		return

	# body is the root "agent" node (CharacterBody2D)
	var agent_script := body.get_node("Code_Container/GD_Swarm_Agent") as SwarmAgent
	if agent_script == null:
		push_warning("CoinTile: Could not find SwarmAgent at Code_Container/GD_Swarm_Agent on %s" % body.name)
		return

	# Give coin
	agent_script.held_coins += 1
	agent_script.update_color_for_coins()
	agent_script.record_coin(sensor.global_position)

	# Hide this coin
	sprite.visible = false
	sensor.hide()
	sensor.set_deferred("monitoring", false)  # <- use sensor here, not self
