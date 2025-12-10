class_name CurrencyDisplay extends PanelContainer

@export var label_gold: Label
@export var label_gems: Label

func _ready() -> void:
	# Initial Update
	_update_ui()
	
	# Connect Signals
	GameEconomy.gold_updated.connect(_on_gold_updated)
	GameEconomy.gems_updated.connect(_on_gems_updated)

func _update_ui() -> void:
	if label_gold:
		label_gold.text = str(GameEconomy.gold)
	if label_gems:
		label_gems.text = str(GameEconomy.gems)

func _on_gold_updated(new_amount: int) -> void:
	if label_gold:
		label_gold.text = str(new_amount)

func _on_gems_updated(new_amount: int) -> void:
	if label_gems:
		label_gems.text = str(new_amount)
