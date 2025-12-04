class_name ShopPopup extends Control

# Ana sisteme haber vermek için sinyaller
signal closed
signal purchase_success

# ---------------------------------------------------------
# REFERANSLAR (Inspector'dan atanacaklar)
# ---------------------------------------------------------
@export_group("Internal Refs")
@export var content_pivot: Control # Büyüyüp küçülecek olan Panel/Pencere
@export var btn_close: Button      # Çarpı (X) butonu
@export var btn_buy: Button        # Satın Al butonu
@export var background_dim: ColorRect # Arkadaki karartı

func _ready() -> void:
	# Başlangıçta gizle
	visible = false
	
	# Butonları bağla
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)
	if btn_buy:
		btn_buy.pressed.connect(_on_buy_pressed)

# DIŞARIDAN ÇAĞRILACAK FONKSİYON
func open() -> void:
	visible = true
	# Animasyon: Önce karartı gelir, sonra pencere büyür
	if background_dim:
		background_dim.modulate.a = 0.0
		var t = create_tween()
		t.tween_property(background_dim, "modulate:a", 1.0, 0.2)
	
	if content_pivot:
		content_pivot.scale = Vector2.ZERO
		content_pivot.pivot_offset = content_pivot.size / 2 # Ortadan büyümesi için
		
		var t2 = create_tween()
		t2.tween_property(content_pivot, "scale", Vector2.ONE, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_pressed() -> void:
	# Kapanış animasyonu
	var t = create_tween()
	if content_pivot:
		t.tween_property(content_pivot, "scale", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	t.tween_callback(func(): 
		visible = false
		closed.emit() # Ana ekrana kapandığını haber ver
	)

func _on_buy_pressed() -> void:
	print("💰 Satın alma simülasyonu başarılı!")
	# Burada gerçek para/elmas ekleme kodu olur
	purchase_success.emit()
	_on_close_pressed() # Satın alınca da kapansın
