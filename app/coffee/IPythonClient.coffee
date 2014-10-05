zmq = require "zmq"
{EventEmitter} = require "events"
uuid = require "uuid"
crypto = require "crypto"

module.exports = class IPythonClient extends EventEmitter
	@createClient: (config) ->
		return new IPythonClient(config)
	
	constructor: (@config) ->
		@session = @_generateId()
		@identity = @_generateId()
		@_messageCallbacks = {}
		
		@_createSockets()
		@_listenForReplies()
		@_startHeartbeats()
	
	sendMessage: (type, content, metadata = {}, callback = (error, reply) ->) ->
		# Optional metadata argument
		if typeof(metadata) == "function"
			callback = metadata
			metadata = {}
		
		msg_id = @_generateId()
		
		header = JSON.stringify {
			session: @session
			username: @username or process.env.USER or "unknown"
			msg_id: msg_id
			msg_type: type
		}
		parent_header = JSON.stringify {}
		content = JSON.stringify content
		metadata = JSON.stringify metadata
		
		signature = @_signMessage(header, parent_header, content, metadata)
		
		message = [
			@identity
			"<IDS|MSG>"
			signature
			header
			parent_header
			metadata
			content
		]
				
		@sockets.shell.send message
		
		@_messageCallbacks[msg_id] = callback
		
	_signMessage: (header, parent_header, content, metadata) ->
		return "" if !@config.key? or @config.key == ""
		
		hmac = crypto.createHmac("sha256", @config.key)
		hmac.update(header)
		hmac.update(parent_header)
		hmac.update(content)
		hmac.update(metadata)
		
		return hmac.digest("hex")
		
	_generateId: () -> uuid.v4()
		
	_createSockets: () ->
		@sockets = {}
		
		@sockets.hb = zmq.createSocket("req")
		@sockets.hb.connect "tcp://#{@config.ip}:#{@config.hb_port}"
		@sockets.shell = zmq.createSocket("dealer")
		@sockets.shell.connect "tcp://#{@config.ip}:#{@config.shell_port}"
		
	_listenForReplies: () ->
		@sockets.shell.on "message", (args...) =>
			@_handleMessage(args...)
			
	_handleMessage: (args...) ->
		args = args.map (a) -> a.toString()
		identities = []
		while (args.length > 0 and (identity = args.shift()) != "<IDS|MSG>")
			identities.push(identity)

		[signature, header, parent_header, metadata, content] = args
		
		if signature != @_signMessage(header, parent_header, metadata, content)
			return @_handleError(new Error("invalid signature in reply from kernel"))
		
		header = JSON.parse(header)
		parent_header = JSON.parse(parent_header)
		metadata = JSON.parse(metadata)
		content = JSON.parse(content)
		
		callback = @_messageCallbacks[parent_header.msg_id]
		delete @_messageCallbacks[parent_header.msg_id]
		
		callback?(null, content, metadata)
		
	HEARTBEAT_INTERVAL: 1000 # milliseconds
	_startHeartbeats: () ->
		setInterval () =>
			@_sendHeartbeat()
		, @HEARTBEAT_INTERVAL
		
		@_sendHeartbeat()
		
		@sockets.hb.on "message", (data) =>
			@last_heartbeat = data.toString()
			@emit "heartbeat", @last_heartbeat
		
	_sendHeartbeat: () ->
		@sockets.hb.send Date.now()
		
	_handleError: (error) ->
		throw error
		
	