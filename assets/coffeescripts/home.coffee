initApp ->
  document.getElementById('CreateChannelForm').addEventListener 'submit', (event) ->
    event.preventDefault()
    window.location = '/play/' + document.getElementById('CreateChannelName').value