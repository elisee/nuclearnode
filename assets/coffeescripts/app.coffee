$(document).ready ->
  console.log 'hello world'
  $('body').append JST['example']( what: 'client-side' )