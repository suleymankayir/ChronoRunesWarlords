extends Control

signal resume_requested
signal quit_requested

@onready var resume_btn: Button = $VBoxContainer/ResumeButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# CRITICAL: Always process.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Basic Input Validation
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	_unpause_and_close()
	resume_requested.emit()

func _on_quit_pressed() -> void:
	# Unpause first to allow main game to save/process scene change
	get_tree().paused = false
	quit_requested.emit()
	_close_self()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_resume_pressed()

func _unpause_and_close() -> void:
	get_tree().paused = false
	_close_self()

func _close_self() -> void:
	# Smart Cleanup: If we are wrapped in a temporary CanvasLayer, free THAT.
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()
