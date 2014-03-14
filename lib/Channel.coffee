ChannelLogic = require './ChannelLogic'

chatSettings = 
  maxRecentMessages: 3
  minRecentMessageInterval: 2000
  maxHellbanPoints: 5

module.exports = class Channel

  constructor: (@engine, @name, @service) ->
    @public =
      users: []
      actors: []

    @sockets = []
    @usersByAuthId = {}
    @actorsByAuthId = {}

    @logic = new ChannelLogic @

  broadcast: (message, data, sockets=@sockets) ->
    socket.emit message, data for socket in sockets
    return

  log: (message) -> @engine.log "[#{@service}:#{@name}] #{message}"


  #----------------------------------------------------------------------------
  # User management
  addSocket: (socket) ->
    socket.user = @usersByAuthId[ socket.handshake.user.authId ] ? @createUser socket.handshake.user
    @log "socket #{socket.id} (#{socket.handshake.address.address}) added to user #{socket.user.public.displayName}"

    socket.user.sockets.push socket
    @sockets.push socket

    @logic.onSocketAdded socket

    @public.time = Date.now()
    socket.emit 'channelData', @public
    @public.time = null

    socket.on 'chatMessage', (text) =>
      return if typeof text != 'string' or text.length == 0
      text = text.substring 0, 300

      now = Date.now()
      console.log now
      socket.user.chat.recentMessageTimestamps.push now
      if socket.user.chat.recentMessageTimestamps.length > chatSettings.maxRecentMessages
        socket.user.chat.recentMessageTimestamps.splice 0, 1

      console.log now - socket.user.chat.recentMessageTimestamps[0]
      if socket.user.chat.hellbanned
        # User is hellbanned, make it look to them as though their messages have been delivered
        # but don't actually send them to anyone else
        socket.emit 'chatMessage', { userAuthId: socket.user.public.authId, text: text }
      else if socket.user.chat.recentMessageTimestamps.length < chatSettings.maxRecentMessages or now - socket.user.chat.recentMessageTimestamps[0] > chatSettings.minRecentMessageInterval
        @broadcast 'chatMessage', { userAuthId: socket.user.public.authId, text: text }
      else
        socket.user.chat.hellbanPoints++
        socket.emit 'chatMessage', text: 'undelivered'
        console.log socket.user.chat.hellbanPoints

        if socket.user.chat.hellbanPoints >= chatSettings.maxHellbanPoints
          console.log 'hellbanned!'
          socket.user.chat.hellbanned = true
      return

    return

  removeSocket: (socket) ->
    @sockets.splice @sockets.indexOf(socket), 1
    socket.user.sockets.splice socket.user.sockets.indexOf(socket), 1

    @logic.onSocketRemoved socket

    if socket.user.sockets.length == 0
      # User doesn't have any active connections anymore
      @logic.onUserLeft socket.user
      delete @usersByAuthId[ socket.user.public.authId ]
      @public.users.splice @public.users.indexOf(socket.user.public), 1
      @broadcast 'removeUser', socket.user.public.authId

    socket.user = null

    if @sockets.length == 0
      @logic.dispose()
      @logic = null
      @engine.clearChannel this

    return

  createUser: (userProfile) ->
    user =
      sockets: []
      actor: @actorsByAuthId[ userProfile.authId ]
      chat:
        recentMessageTimestamps: []
        hellbanned: false
        hellbanPoints: 0
      public:
        authId: userProfile.authId
        displayName: userProfile.displayName
        pictureURL: userProfile.pictureURL
        isHost: userProfile.serviceHandles[@service]?.toLowerCase() == @name.toLowerCase()

    @usersByAuthId[ user.public.authId ] = user
    @public.users.push user.public
    @logic.onUserJoined user

    @broadcast 'addUser', user.public
    @log "User #{user.public.displayName} created"

    user

