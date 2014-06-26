config = require '../config'
_ = require 'lodash'
ChannelLogic = require './ChannelLogic'

chatSettings = 
  maxRecentMessages: 3
  minRecentMessageInterval: 2000
  maxHellbanPoints: 5

module.exports = class Channel

  constructor: (@engine, @name, @service) ->
    @public =
      welcomeMessage: ''
      guestAccess: 'full'
      bannedUsersByAuthId: {}
      livestream: { service: 'none', channel: '' }

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
  logDebug: (message) -> @engine.logDebug "[#{@service}:#{@name}] #{message}"

  #----------------------------------------------------------------------------
  # User management
  addSocket: (socket) ->
    if socket.request.user.isGuest and @public.guestAccess == 'deny'
      socket.emit 'noGuestsAllowed'
      return socket.disconnect()

    if @public.bannedUsersByAuthId[socket.request.user.authId]?
      socket.emit 'banned'
      return socket.disconnect()

    socket.user = @usersByAuthId[ socket.request.user.authId ] ? @createUser socket.request.user
    @logDebug "socket #{socket.id} (#{socket.handshake.address.address}) added to user #{socket.user.public.displayName}"

    socket.user.sockets.push socket
    @sockets.push socket

    @logic.onSocketAdded socket

    @public.time = Date.now()
    socket.emit 'channelData', @public
    @public.time = null

    socket.on 'chatMessage', (text) =>
      return if typeof text != 'string' or text.length == 0
      # _(socket.user.public.authId).startsWith 'guest:' (waiting for lodash 2.5)
      return if @public.guestAccess == 'noChat' and socket.user.public.authId.substring(0, 'guest:'.length) == 'guest:'

      text = text.substring 0, 300

      now = Date.now()
      socket.user.chat.recentMessageTimestamps.push now
      if socket.user.chat.recentMessageTimestamps.length > chatSettings.maxRecentMessages
        socket.user.chat.recentMessageTimestamps.splice 0, 1

      if socket.user.chat.hellbanned
        # User is hellbanned, make it look to them as though their messages have been delivered
        # but don't actually send them to anyone else
        socket.emit 'chatMessage', { userAuthId: socket.user.public.authId, text: text }
      else if socket.user.chat.recentMessageTimestamps.length < chatSettings.maxRecentMessages or now - socket.user.chat.recentMessageTimestamps[0] > chatSettings.minRecentMessageInterval
        @broadcast 'chatMessage', { userAuthId: socket.user.public.authId, text: text }
      else
        socket.user.chat.hellbanPoints++
        socket.emit 'chatMessage', text: 'undelivered'

        if socket.user.chat.hellbanPoints >= chatSettings.maxHellbanPoints
          @log "User #{socket.user.public.displayName} (#{socket.user.public.authId}) has been hellbanned"
          socket.user.chat.hellbanned = true
      return

    socket.on 'settings:room.welcomeMessage', (text) =>
      return if socket.user.public.role not in [ 'host', 'hubAdministrator' ]
      @public.welcomeMessage = text.substring 0, 300
      @broadcast 'settings:room.welcomeMessage', @public.welcomeMessage

    socket.on 'settings:room.guestAccess', (guestAccess) =>
      return if socket.user.public.role not in [ 'host', 'hubAdministrator' ]
      return if guestAccess not in [ 'full', 'noChat', 'deny' ]

      @public.guestAccess = guestAccess
      @broadcast 'settings:room.guestAccess', @public.guestAccess

      if guestAccess == 'deny'
        for authId, connectedUser of @usersByAuthId
          # if _(authId).startsWith 'guest:' (waiting for lodash 2.5)
          if authId.substring(0, 'guest:'.length) == 'guest:'
            for userSocket in connectedUser.sockets
              userSocket.emit 'noGuestsAllowed'
              userSocket.disconnect()

      return

    socket.on 'banUser', (user) =>
      return if socket.user.public.role not in [ 'host', 'hubAdministrator' ]
      return if typeof(user) != 'object' or typeof(user.authId) != 'string' or typeof(user.displayName) != 'string'
      
      bannedUserInfo =
        authId: user.authId
        displayName: user.displayName

      return if @public.bannedUsersByAuthId[bannedUserInfo.authId]?

      @public.bannedUsersByAuthId[bannedUserInfo.authId] = bannedUserInfo

      bannedUser = @usersByAuthId[bannedUserInfo.authId]
      if bannedUser?
        for bannedUserSocket in bannedUser.sockets
          bannedUserSocket.emit 'banned'
          bannedUserSocket.disconnect()

      @broadcast 'banUser', bannedUserInfo

    socket.on 'unbanUser', (userAuthId) =>
      return if socket.user.public.role not in [ 'host', 'hubAdministrator' ]
      return if typeof(userAuthId) != 'string' or userAuthId.length == 0

      bannedUserInfo = @public.bannedUsersByAuthId[userAuthId]
      return if ! bannedUserInfo?
      delete @public.bannedUsersByAuthId[userAuthId]

      @broadcast 'unbanUser', bannedUserInfo

    socket.on 'settings:livestream', (service, channel) =>
      return if service not in [ 'none', 'twitch', 'hitbox' ]
      return if ! /^[A-Za-z0-9_]+$/.test channel

      @public.livestream = { service, channel }
      @broadcast 'settings:livestream', @public.livestream

    return

  removeSocket: (socket) ->
    index = @sockets.indexOf(socket)
    return if index == -1

    @sockets.splice @sockets.indexOf(socket), 1
    socket.user.sockets.splice socket.user.sockets.indexOf(socket), 1

    @logic.onSocketRemoved socket

    if socket.user.sockets.length == 0
      # User doesn't have any active connections anymore
      @logic.onUserLeft socket.user
      delete @usersByAuthId[ socket.user.public.authId ]
      @public.users.splice @public.users.indexOf(socket.user.public), 1
      @broadcast 'removeUser', socket.user.public.authId

      # If user was the host of an unauthenticated channel
      # Make the next user the host instead
      if @service.length == 0 and socket.user.public.role == 'host' and @public.users.length > 0
        newHostPublicUser = @public.users[0]
        newHostPublicUser.role = 'host'
        @broadcast 'setUserRole', userAuthId: newHostPublicUser.authId, role: newHostPublicUser.role

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
        serviceHandles: userProfile.serviceHandles
        role: ''

    if userProfile.isHubAdministrator
      user.public.role = 'hubAdministrator'
    else if @service.length > 0
      # Make the authenticated channel's owner its host
      if userProfile.serviceHandles?[@service]?.toLowerCase() == @name.toLowerCase()
        user.public.role = 'host'
    else if @public.users.length == 0
      # Make the first user to join an unauthenticated channel its host
      user.public.role = 'host'

    @usersByAuthId[ user.public.authId ] = user
    @public.users.push user.public
    @logic.onUserJoined user

    @broadcast 'addUser', user.public
    @logDebug "User #{user.public.displayName} created"

    user

