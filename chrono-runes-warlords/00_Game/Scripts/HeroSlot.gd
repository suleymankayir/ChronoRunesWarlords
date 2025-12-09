class_name HeroSlot extends TextureButton

# --- SIGNALS ---
signal hero_selected(data: CharacterData)

# --- DATA ---
@export var slot_data: CharacterData

func _ready() -> void:
    # Set the button's texture if data exists
    if slot_data and slot_data.portrait:
        texture_normal = slot_data.portrait
        ignore_texture_size = true
        stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    
    # Connect the internal pressed signal
    pressed.connect(_on_pressed)

func _on_pressed() -> void:
    if slot_data:
        hero_selected.emit(slot_data)
