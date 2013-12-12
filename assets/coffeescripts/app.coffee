$(document).ready ->
  console.log 'hello world'
  $('body').append Templates['example']( what: 'client-side' )