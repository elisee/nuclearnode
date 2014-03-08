config = require '../config'
passport = require 'passport'
signedRequest = require 'signed-request'
Channel = require('./Channel')

module.exports = engine =
  channelsById: {}

  loginServicesById:
    steam: "Steam"
    twitch: "Twitch"
    twitter: "Twitter"
    facebook: "Facebook"
    google: "Google+"

  init: (app, io, callback) ->

    app.get '/', (req, res) -> res.redirect "#{config.hubBaseURL}/apps/#{config.appId}"

    app.post '/', passport.authenticate('nuclearhub'), (req, res) ->
      channelInfos = ( { name: channel.name, service: channel.service, users: channel.public.users.length, actors: channel.public.actors.length } for channelName, channel of engine.channelsById )

      res.expose user: req.user
      res.render 'home',
        config: config
        path: req.path
        apps: req.user.apps
        loginServicesById: engine.loginServicesById
        user: req.user
        channelInfos: channelInfos

    app.param 'channel', (req, res, next, channel) -> if /^[A-Za-z0-9_-]+$/.exec(channel) then next() else res.send 404

    validateService = (req, res, next) ->
      req.params.service ?= null
      return res.send 404 if config.channels.services.indexOf(req.params.service) == -1
      next()

    app.get '/play/:service?/:channel', validateService, (req, res) ->
      if req.params.service?
        res.redirect "#{config.hubBaseURL}/apps/#{config.appId}/#{config.channels.prefix}/#{req.params.service}/#{req.params.channel}"
      else
        res.redirect "#{config.hubBaseURL}/apps/#{config.appId}/#{config.channels.prefix}/#{req.params.channel}"

    app.post '/play/:service?/:channel', validateService, passport.authenticate('nuclearhub'), (req, res) ->
      isHost = req.params.service? and req.user.serviceHandles[req.params.service]?.toLowerCase() == req.params.channel.toLowerCase()

      channel =
        name: req.params.channel
        service: if req.params.service? then { id: req.params.service, name: engine.loginServicesById[req.params.service] } else null

      res.expose channel: channel, isHost: isHost, user: req.user
      res.render 'main',
        config: config
        path: req.path
        apps: req.user.apps
        loginServicesById: engine.loginServicesById
        user: req.user
        channel: channel
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

    socket.on 'joinChannel', (service, channelName) ->
      return if typeof channelName != 'string' or socket.channel?
      return if config.channels.services.indexOf(service) == -1

      service = '' if ! service?
      channelId = "#{service}:#{channelName.toLowerCase()}"
      
      socket.channel = engine.channelsById[channelId]
      if ! socket.channel?
        socket.channel = new Channel engine, channelName, service
        engine.channelsById[channelId] = socket.channel
      
      socket.channel.addSocket socket
      return
    
    return
  
  clearChannel: (channel) ->
    channel.log "Clearing channel"
    delete engine.channelsById["#{channel.service}:#{channel.name.toLowerCase()}"]
    
    return
