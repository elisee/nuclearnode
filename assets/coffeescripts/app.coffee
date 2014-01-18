$(document).ready -> i18n.init window.app.i18nOptions, ->
  $('body').append JST['example']( i18n: i18n, what: i18n.t('clientSide') )