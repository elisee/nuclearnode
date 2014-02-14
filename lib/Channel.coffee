module.exports = class Channel
  constructor: (@engine, @name) ->
    @public =
      players: []

    @sockets = []
    @playersByAuthId = {}

  broadcast: (message, data, sockets=@sockets) ->
    socket.emit message, data for socket in sockets
    return

  log: (message) -> @engine.log "[#{@name}] #{message}"

  #----------------------------------------------------------------------------
  # Player management
  addSocket: (socket) ->
    @log "socket #{socket.id} (#{socket.handshake.address.address}) added to channel"

    @addPlayerSocket socket if socket.handshake.user.logged_in

    socket.emit 'channelData', @public
    @sockets.push socket

    socket.on 'disconnect', =>
      @sockets.splice @sockets.indexOf(socket), 1
      @removePlayerSocket socket if socket.player?
      @engine.clearChannel this if @sockets.length == 0
    
    return

  addPlayerSocket: (socket) ->
    socket.player = @playersByAuthId[ socket.handshake.user.authId ]
    if ! socket.player? then socket.player = @createPlayer socket.handshake.user
    socket.player.public.connected = true
    socket.player.sockets.push socket
    @log "socket #{socket.id} (#{socket.handshake.address.address}) added to player #{socket.player.public.displayName}"

    # @setupHostEvents socket if socket.player.public.isHost
    # @setupPlayerEvents socket

    return

  removePlayerSocket: (socket) ->
    socket.player.sockets.splice socket.player.sockets.indexOf(socket), 1

    for key in socket.watchedKeys
      watchingSockets = @watchingSocketsByKeys[key]
      watchingSockets.splice watchingSockets.indexOf(socket), 1

    return if socket.player.sockets.length > 0

    # Player doesn't have any active connections anymore
    @public.players.splice @public.players.indexOf(socket.player.public), 1
    delete @playersByAuthId[ socket.player.public.authId ]
    @broadcast 'removePlayer', socket.player.public.authId
    return

  createPlayer: (user) ->
    player =
      sockets: []
      public:
        authId: user.authId
        displayName: user.displayName
        pictureURL: user.pictureURL
        isHost: user.twitterHandle == @name
        connected: false
    
    @public.players.push player.public
    @playersByAuthId[ player.public.authId ] = player
    
    @broadcast 'addPlayer', player.public
    
    @log "player #{player.public.displayName} created"
    player
