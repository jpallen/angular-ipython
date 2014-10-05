express = require("express")
morgan = require "morgan"
livedb = require "livedb"
Duplex = require('stream').Duplex
browserChannel = require('browserchannel').server

app = express()
backend = livedb.client(livedb.memory())
sharejs = require('share')
share = sharejs.server.createClient(backend: backend)

app.use morgan("dev")

app.use(express.static(__dirname + "/public"))
app.use(express.static(sharejs.scriptsDir))
app.set("views", __dirname + "/app/views")
app.set("view engine", "jade")

app.use browserChannel (client) ->
	stream = new Duplex({objectMode: true})
	stream._read = () ->
	stream._write = (chunk, encoding, callback) ->
		if (client.state != 'closed')
			client.send(chunk)
		callback()

	client.on 'message', (data) ->
		stream.push(data)

	client.on 'close', (reason) ->
		stream.push(null)
		stream.emit('close')

	stream.on 'end', () ->
		client.close()

	return share.listen(stream)

app.get "/", (req, res, next) ->
	res.render "index"

app.listen 5000, "localhost", (error) ->
	throw error if error?
	console.log "Listening on port 6000"