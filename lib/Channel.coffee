config = require '../config'
_ = require 'lodash'
http = require 'http'
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
      livestreams: []

      users: []
      actors: []

    for i in [0...config.public.maxLivestreams]
      @public.livestreams.push { service: 'none', channel: '' }

    if @service in ['twitch', 'hitbox']
      @public.livestreams[0].service = @service
      @public.livestreams[0].channel = @name

    @sockets = []
    @usersByAuthId = {}
    @actorsByAuthId = {}

    @adminUsers = []
    @modUsers = []

    @logic = new ChannelLogic @

  broadcast: (message, data, sockets=@sockets) ->
    socket?.emit message, data for socket in sockets
    return @logic?

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
        return if ! @broadcast 'chatMessage', { userAuthId: socket.user.public.authId, text: text }
      else
        socket.user.chat.hellbanPoints++
        socket.emit 'chatMessage', text: 'undelivered'

        if socket.user.chat.hellbanPoints >= chatSettings.maxHellbanPoints
          @log "User #{socket.user.public.displayName} (#{socket.user.public.authId}) has been hellbanned"
          socket.user.chat.hellbanned = true
      return

    socket.on 'settings:room.welcomeMessage', (text) =>
      return if @adminUsers.indexOf(socket.user) == -1 or typeof(text) != 'string'
      @public.welcomeMessage = text.substring 0, 300
      return if ! @broadcast 'settings:room.welcomeMessage', @public.welcomeMessage

    socket.on 'settings:room.guestAccess', (guestAccess) =>
      return if @adminUsers.indexOf(socket.user) == -1
      return if guestAccess not in [ 'full', 'noChat', 'deny' ]

      @public.guestAccess = guestAccess
      return if ! @broadcast 'settings:room.guestAccess', @public.guestAccess

      if guestAccess == 'deny'
        for authId, connectedUser of @usersByAuthId
          # if _(authId).startsWith 'guest:' (waiting for lodash 2.5)
          if authId.substring(0, 'guest:'.length) == 'guest:'
            # Warning: socket.io fires the 'disconnect' event synchronously
            # when disconnecting manually. That's why we're using a while loop
            # rather than iterating over the array
            while connectedUser.sockets.length > 0
              connectedUser.sockets[0].emit 'noGuestsAllowed'
              connectedUser.sockets[0].disconnect()

      return

    socket.on 'banUser', (userToBan) =>
      return if @adminUsers.indexOf(socket.user) == -1 and @modUsers.indexOf(socket.user) == -1
      return if ! userToBan? or typeof(userToBan) != 'object' or typeof(userToBan.authId) != 'string' or typeof(userToBan.displayName) != 'string'

      bannedUser = @usersByAuthId[userToBan.authId]
      if ! bannedUser?
        @log "Cannot ban #{userToBan.displayName} (#{userToBan.authId}), no such user"
        return

      if @adminUsers.indexOf(bannedUser) != -1 or @modUsers.indexOf(bannedUser) != -1
        @log "Cannot ban #{userToBan.displayName} (#{userToBan.authId}), admin or mod"
        return

      bannedUserInfo =
        authId: userToBan.authId
        displayName: userToBan.displayName

      if @public.bannedUsersByAuthId[bannedUserInfo.authId]?
        @log "Cannot ban #{bannedUserInfo.displayName} (#{bannedUserInfo.authId}), already banned"
        return

      @public.bannedUsersByAuthId[bannedUserInfo.authId] = bannedUserInfo

      # Warning: socket.io fires the 'disconnect' event synchronously
      # when disconnecting manually. That's why we're using a while loop
      # rather than iterating over the array
      while bannedUser.sockets.length > 0
        bannedUser.sockets[0].emit 'banned'
        bannedUser.sockets[0]?.disconnect()

      return if ! @broadcast 'banUser', bannedUserInfo
      return

    socket.on 'unbanUser', (userAuthId) =>
      return if @adminUsers.indexOf(socket.user) == -1 and @modUsers.indexOf(socket.user) == -1
      return if typeof(userAuthId) != 'string' or userAuthId.length == 0

      bannedUserInfo = @public.bannedUsersByAuthId[userAuthId]
      return if ! bannedUserInfo?
      delete @public.bannedUsersByAuthId[userAuthId]

      return if ! @broadcast 'unbanUser', bannedUserInfo
      return

    socket.on 'modUser', (userToMod) =>
      return if @adminUsers.indexOf(socket.user) == -1
      return if ! userToMod? or typeof(userToMod) != 'object' or typeof(userToMod.authId) != 'string' or typeof(userToMod.displayName) != 'string'

      moddedUser = @usersByAuthId[userToMod.authId]
      return if ! moddedUser? or @adminUsers.indexOf(moddedUser) != -1 or @modUsers.indexOf(moddedUser) != -1
      return if moddedUser.public.role != ''

      @modUsers.push moddedUser
      moddedUser.public.role = 'moderator'

      return if ! @broadcast 'setUserRole', userAuthId: moddedUser.public.authId, role: moddedUser.public.role
      return

    socket.on 'unmodUser', (userAuthId) =>
      return if @adminUsers.indexOf(socket.user) == -1
      return if typeof(userAuthId) != 'string' or userAuthId.length == 0

      moddedUser = @usersByAuthId[userAuthId]
      return if ! moddedUser?
      index = @modUsers.indexOf(moddedUser)
      return if index == -1
      @modUsers.splice index, 1
      moddedUser.public.role = ''

      return if ! @broadcast 'setUserRole', userAuthId: userAuthId, role: moddedUser.public.role
      return

    socket.on 'settings:livestream', (index, service, channel) =>
      return if service not in [ 'none', 'twitch', 'hitbox', 'dailymotion', 'talkgg' ]
      index |= 0
      return if index < 0 or index >= config.public.maxLivestreams

      if service != 'talkgg'
        return if ! /^[A-Za-z0-9_-]+$/.test(channel)
        @public.livestreams[index] = { service, channel }
        return if ! @broadcast 'settings:livestream', { index, service, channel }
      else
        http.get('http://www.talk.gg/direct', (res) =>
          if res.statusCode == 302
            location = res.headers.location.split('/')
            channel = location[location.length - 1]

            @public.livestreams[index] = { service, channel }
            return if ! @broadcast 'settings:livestream', { index, service, channel }
          else
            console.log "Could not get talk.gg channel:"
            console.log "Got unexpected status code #{res.statusCode}"
        ).on 'error', (err) ->
          console.log 'Could not get talk.gg channel:'
          console.log err

    @logic.onSocketAdded socket
    return

  removeSocket: (socket) ->
    index = @sockets.indexOf(socket)
    return if index == -1

    @sockets.splice index, 1
    socket.user.sockets.splice socket.user.sockets.indexOf(socket), 1

    @logic.onSocketRemoved socket

    if socket.user.sockets.length == 0
      # User doesn't have any active connections anymore
      @logic.onUserLeft socket.user
      delete @usersByAuthId[ socket.user.public.authId ]
      @public.users.splice @public.users.indexOf(socket.user.public), 1
      return if ! @broadcast 'removeUser', socket.user.public.authId

      # Remove from admin list if applicable
      adminIndex = @adminUsers.indexOf(socket.user)
      if adminIndex != -1
        @adminUsers.splice adminIndex, 1

        # If there are no hosts left in an unauthenticated channel
        # Make the oldest user a host
        if @adminUsers.length == 0 and @service.length == 0 and @public.users.length > 0
          newHostPublicUser = @public.users[0]
          newHostPublicUser.role = 'host'
          newHostUser = @usersByAuthId[newHostPublicUser.authId]
          @adminUsers.push newHostUser

          return if ! @broadcast 'setUserRole', userAuthId: newHostPublicUser.authId, role: newHostPublicUser.role

      # Remove from mod list if applicable
      modIndex = @modUsers.indexOf(socket.user)
      @modUsers.splice modIndex, 1 if modIndex != -1

    socket.user = null

    if @sockets.length == 0 and @logic?
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
      @adminUsers.push user
    else if @service.length > 0
      # Make the authenticated channel's owner a host
      if userProfile.serviceHandles?[@service]?.toLowerCase() == @name.toLowerCase()
        user.public.role = 'host'
        @adminUsers.push user
    else if @public.users.length == 0 and config.channels.services.length > 0
      # Make the first user to join an unauthenticated channel a host
      user.public.role = 'host'
      @adminUsers.push user

    @usersByAuthId[ user.public.authId ] = user
    @public.users.push user.public
    @logic.onUserJoined user

    return if ! @broadcast 'addUser', user.public
    @logDebug "User #{user.public.displayName} created"

    user
