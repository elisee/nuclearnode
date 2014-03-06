config = require '../config'
passport = require 'passport'
signedRequest = require 'signed-request'
Channel = require('./Channel')

module.exports = engine =
  channelsByName: {}

  loginServices: [
      id: 'steam'
      name: 'Steam'
    ,
      id: 'twitch'
      name: 'Twitch'
    ,
      id: 'twitter'
      name: 'Twitter'
    ,
      id: 'facebook'
      name: 'Facebook'
    ,
      id: 'google'
      name: 'Google+'
  ]

  init: (app, io, callback) ->

    app.get '/', (req, res) -> res.redirect "#{config.hubBaseURL}/apps/#{config.appId}"

    app.post '/', passport.authenticate('nuclearhub'), (req, res) ->
      channelInfos = ( { name: channelName, users: channel.public.users.length } for channelName, channel of engine.channelsByName )

      res.expose user: req.user
      res.render 'nuclearnode/index',
        config: config
        apps: req.user.apps
        loginServices: engine.loginServices
        user: req.user
        channelInfos: channelInfos

    app.get '/play/:channel', (req, res) ->
      channelName = req.params.channel.toLowerCase()
      res.redirect "#{config.hubBaseURL}/apps/#{config.appId}/#{channelName}"


    app.post '/play/:channel', passport.authenticate('nuclearhub'), (req, res) ->
      channelName = req.params.channel.toLowerCase()
      isHost = false # TODO: Allow registering channels
      res.expose channel: { name: channelName }, isHost: isHost, user: req.user
      res.render 'nuclearnode/channel',
        config: config
        apps: req.user.apps
        loginServices: engine.loginServices
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
      socket.channel.removeSocket socket if socket.channel?

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