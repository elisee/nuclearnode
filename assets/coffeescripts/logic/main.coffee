window.channel.logic =
  
  onChannelDataReceived: ->
    serverTimeOffset = Date.now() - channel.data.time
    channel.data.stateStartTime += serverTimeOffset if channel.data.stateStartTime?

  onPlayerAdded: (player) ->

  onPlayerRemoved: (player) ->