class_name GoldShopPopup extends Control

signal purchase_successful
signal popup_closed

@export var title_label: Label
@export var description_label: Label
@export var buy_button: Button
@export var close_button: Button

var _needed_gold: int = 0
var _gem_cost: int = 0

func _ready() -> void:
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	hide()

func open(missing_gold_amount: int) -> void:
	_needed_gold = missing_gold_amount
	# Calculate gem cost: 1 Gem = 100 Gold. Round up.
	_gem_cost = ceili(float(missing_gold_amount) / 100.0)
	
	# Calculate actual gold given (pack size)
	var gold_to_give = _gem_cost * 100
	
	if description_label:
		description_label.text = "Get %d Gold for %d Gems?" % [gold_to_give, _gem_cost]
		
	if buy_button:
		buy_button.text = "SATIN AL (%d Elmas)" % _gem_cost
		
	show()

func _on_buy_pressed() -> void:
	if GameEconomy.has_enough_gems(_gem_cost):
		if GameEconomy.spend_gems(_gem_cost):
			var gold_to_give = _gem_cost * 100
			GameEconomy.add_gold(gold_to_give)
			purchase_successful.emit()
			GameEconomy.gold_updated.emit(GameEconomy.gold) # Ensure UI updates if not automatic
			_on_close_pressed()
	else:
		print("Not enough gems! Go to Real Money Store")

func _on_close_pressed() -> void:
	hide()
	popup_closed.emit()
