extends Control

@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var close_button: Button

func _ready() -> void:
	# Use 'Audio' Singleton to init values
	if Audio:
		if music_slider:
			music_slider.value = Audio.music_volume
		if sfx_slider:
			sfx_slider.value = Audio.sfx_volume
			
	# Connect signals
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_value_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func _on_music_slider_value_changed(value: float) -> void:
	if Audio:
		Audio.set_music_volume(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	if Audio:
		Audio.set_sfx_volume(value)

func _on_close_button_pressed() -> void:
	queue_free()
