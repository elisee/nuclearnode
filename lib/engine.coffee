config = require '../config'
passport = require 'passport'
signedRequest = require 'signed-request'
_ = require 'underscore'
Channel = require('./Channel')

module.exports = engine =
  channelsById: {}

  loginServices: [ 'steam', 'twitch', 'twitter', 'facebook', 'google' ]

  init: (app, io, callback) ->

    app.get '/', (req, res) -> res.redirect "#{config.hubBaseURL}/apps/#{config.appId}"

    app.post '/', passport.authenticate('nuclearhub'), (req, res) ->

      channelInfosById = {}

      for channelId, channel of engine.channelsById

        channelInfosById[channelId] = 
          name: channel.name
          service: ( if channel.service != '' then channel.service else null )
          users: channel.public.users.length
          actors: channel.public.actors.length

      for service, handle of req.user.serviceHandles
        continue if config.channels.services.indexOf(service) == -1 or ! handle?
        channelId = "#{service}:#{handle.toLowerCase()}"
        
        channelInfo = channelInfosById[channelId]
        if ! channelInfo?
          channelInfo = name: handle, service: service, users: 0, actors: 0
          channelInfosById[channelId] = channelInfo

        channelInfo.isMine = true

      channelInfos = ( channelInfo for channelId, channelInfo of channelInfosById )
      channelInfos = _.sortBy channelInfos, (x) -> -( x.users + if x.isMine then 1000000 else 0 )

      res.expose user: req.user
      res.render 'home',
        config: config
        path: req.path
        apps: req.user.apps
        loginServices: engine.loginServices
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
      channel =
        name: req.params.channel
        service: if req.params.service? then req.params.service else null

      res.expose channel: channel, user: req.user
      res.render 'main',
        config: config
        path: req.path
        apps: req.user.apps
        loginServices: engine.loginServices
        user: req.user
        channel: channel
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
