i18n.init window.app.i18nOptions, ->
  document.querySelector('body').insertAdjacentHTML 'beforeend', JST['example']( i18n: i18n, what: i18n.t('clientSide') )