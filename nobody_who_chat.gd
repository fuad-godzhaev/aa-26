extends NobodyWhoChat

func _ready():
	# configure the node (feel free to do this in the UI)
	self.system_prompt = "You are an evil wizard."
	self.model_node = get_node("../NobodyWhoModel")

	# connect signals to signal handlers
	self.response_updated.connect(_on_response_updated)
	self.response_finished.connect(_on_response_finished)

	# Start the worker, this is not required, but recommended to do in
	# the beginning of the program to make sure it is ready
	# when the user prompts the chat the first time. This will be called
	# under the hood when you use `ask()` as well.
	self.start_worker()

	self.ask("How are you?")

func _on_response_updated(token):
	# this will print every time a new token is generated
	print(token)

func _on_response_finished(response):
	# this will print when the entire response is finished
	print(response)
