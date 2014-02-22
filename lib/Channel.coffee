ChannelLogic = require './ChannelLogic'

module.exports = class Channel
  constructor: (@engine, @name) ->
    @public = {}

    @sockets = []
    @playersByAuthId = {}

    @logic = new ChannelLogic @

  broadcast: (message, data, sockets=@sockets) ->
    socket.emit message, data for socket in sockets
    return

  log: (message) -> @engine.log "[#{@name}] #{message}"

  #----------------------------------------------------------------------------
  # Player management
  addSocket: (socket) ->
    socket.player = @playersByAuthId[ socket.handshake.user.authId ] ? @createPlayer socket.handshake.user
    @log "socket #{socket.id} (#{socket.handshake.address.address}) added to player #{socket.player.public.displayName}"

    socket.player.sockets.push socket
    @sockets.push socket

    @logic.onSocketAdded socket
    socket.emit 'channelData', @public

    socket.on 'chatMessage', (text) =>
      return if typeof text != 'string' or text.length == 0
      text = text.substring 0, 300
      @broadcast 'chatMessage', { playerAuthId: socket.player.public.authId, text: text }
      return

    return

  removeSocket: (socket) ->
    @sockets.splice @sockets.indexOf(socket), 1
    socket.player.sockets.splice socket.player.sockets.indexOf(socket), 1

    @logic.onSocketRemoved socket

    if socket.player.sockets.length == 0
      # Player doesn't have any active connections anymore
      @logic.onPlayerLeft socket.player
      delete @playersByAuthId[ socket.player.public.authId ]
      @broadcast 'removePlayer', socket.player.public.authId

    if @sockets.length == 0
      @logic.dispose()
      @logic = null
      @engine.clearChannel this

    return

  createPlayer: (user) ->
    player =
      sockets: []
      public:
        authId: user.authId
        displayName: user.displayName
        pictureURL: user.pictureURL
        isHost: user.twitterHandle == @name
    
    @playersByAuthId[ player.public.authId ] = player
    @logic.onPlayerJoined player

    @broadcast 'addPlayer', player.public
    @log "player #{player.public.displayName} created"

    player

