config = require '../config'
passport = require 'passport'
signedRequest = require 'signed-request'
Channel = require('./Channel')

module.exports = engine =
  channelsByName: {}

  init: (app, io, callback) ->
    setupUser = (req, res, next) ->
      return next() if req.user?
      # passport.authenticate('dummy')(req, res, next)

    app.get '/play/:channel', (req, res) ->
      channelName = req.params.channel.toLowerCase()
      res.redirect "#{config.hubBaseURL}/apps/#{config.appId}/#{channelName}"

    app.post '/play/:channel', passport.authenticate('nuclearhub'), (req, res) ->
      channelName = req.params.channel.toLowerCase()
      isHost = false # TODO: Allow registering channels
      res.expose channel: { name: channelName }, isHost: isHost, user: req.user
      res.render 'channel',
        apps: req.user.apps
        hubBaseURL: config.hubBaseURL
        appId: config.appId
        appTitle: config.title
        user: req.user
        channel: { name: channelName }
        isHost: isHost
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