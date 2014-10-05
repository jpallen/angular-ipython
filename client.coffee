fs = require "fs"
config = JSON.parse(fs.readFileSync(process.argv[2]))

client = require("./app/coffee/IPythonClient").createClient(config)

client.on "heartbeat", (timestamp) ->
	console.log "Got heartbeat", timestamp
	
client.sendMessage "connect_request", {}, (error, content, metadata) ->
	console.log "REPLY", content, metadata

# shell_socket.on "message", (message) ->
# 	for key, value of arguments
# 		console.log key, value.toString()
# 	
# shell_socket.on "error", (message) ->
# 	console.error message

# message =
# 	header:
# 		msg_id: 1
# 		user: "james"
# 		session: "Session.session"
# 		msg_type: "connect_request"
# 	parent_header: {}
# 	metadata: {}
# 	content: {}
# 	
# ident = "Session.session"
# delim = "<IDS|MSG>"
# signature = ""
# 
# shell_socket.send [
# 	ident
# 	delim
# 	signature
# 	JSON.stringify(message.header)
# 	JSON.stringify(message.parent_header)
# 	JSON.stringify(message.metadata)
# 	JSON.stringify(message.content)
# ]
