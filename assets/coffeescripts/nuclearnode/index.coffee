i18n.init window.app.i18nOptions, ->
  initApp()
  
  document.getElementById('StartChannelForm').addEventListener 'submit', (event) ->
    event.preventDefault()
    window.location = '/play/' + document.getElementById('StartChannelName').value