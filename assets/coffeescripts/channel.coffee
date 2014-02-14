channel = {}

i18n.init window.app.i18nOptions, ->
  channel.socket = io.connect null, reconnect: false
  channel.socket.on 'connect', -> channel.socket.emit 'joinChannel', app.channel

  channel.socket.on 'channelData', (data) ->
    channel.data = data

    for player in channel.data.players
      channel.data.playersByAuthId[player.authId] = player

    return

  channel.socket.on 'addPlayer', (player) ->
    channel.data.players.push player
    channel.data.playersByAuthId[player.authId] = player
    return

  channel.socket.on 'removePlayer', (authId) ->
    player = channel.data.playersByAuthId[authId]
    delete channel.data.playersByAuthId[authId]
    channel.data.players.splice channel.data.players.indexOf(player), 1
    return
