extends Control

@onready var aiText = $TextEdit2
@onready var textEdit = $TextEdit
@onready var aiChat = $NobodyWhoChat

func send_text_to_ai():
	textEdit.editable = false
	aiChat.say(textEdit.text)
	
func _input(event: InputEvent) -> void:
	if(event.is_action("ui_text_newline")):
		send_text_to_ai()

func _on_nobody_who_chat_response_updated(new_token: String) -> void:
	aiText.text += new_token


func _on_nobody_who_chat_response_finished(response: String) -> void:
	textEdit.editable = true
	textEdit.text = ""
