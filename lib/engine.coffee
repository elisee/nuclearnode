config = require '../config'
Channel = require('./Channel')

module.exports = engine =
  channelsByName: {}

  init: (app, io, callback) ->
    app.get '/play/:channel', (req, res) ->
      channelName = req.params.channel.toLowerCase()

      isHost = req.user? and channelName == req.user.twitchtvHandle
      res.expose channel: channelName, isHost: isHost, authId: if req.user? then req.user.authId else null
      res.render 'channel', { title: "#{channelName} - #{config.title}", user: req.user, channel: channelName, isHost: isHost }
      return

    engine.io = io
    engine.io.sockets.on 'connection', engine.setupSocket

    callback()
    return

  log: (message) -> console.log new Date().toISOString() + " - #{message}"

  setupSocket: (socket) ->
    engine.log "#{socket.id} (#{socket.handshake.address.address}) connected"

    socket.on 'disconnect', ->
      engine.log "#{socket.id} (#{socket.handshake.address.address}) disconnected"

    socket.on 'joinChannel', (channelName) ->
      return if typeof channelName != 'string' or socket.channel?
      channelName = channelName.toLowerCase()
      
      socket.channel = engine.channelsByName[channelName]
      if ! socket.channel?
        socket.channel = new Channel engine, channelName
        engine.channelsByName[channelName] = socket.channel
      
      socket.channel.addSocket socket
      return
    
    return
  
  clearChannel: (channel) ->
    engine.log "Clearing channel #{channel.name}"
    delete engine.channelsByName[channel.name]
    
    return