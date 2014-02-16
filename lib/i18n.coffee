i18next = require 'i18next'
marked = require 'marked'

cachedMarkdownsByLocale = {}
markdownI18nCache = (i18n, key) ->
  cachedMarkdowns = cachedMarkdownsByLocale[i18n.locale()]
  if ! cachedMarkdowns?
    cachedMarkdowns = {}
    cachedMarkdownsByLocale[i18n.locale()] = cachedMarkdowns

  html = cachedMarkdowns[key]
  if ! html?
    html = marked i18n.t key
    cachedMarkdowns[key] = html

  html

module.exports = (app, namespaces=[]) ->
  namespaces.unshift 'common'

  options = 
    ns: { namespaces: namespaces, defaultNs: 'common' }
    fallbackLng: 'en'
    interpolationPrefix: '%{'
    interpolationSuffix: '}'
    resGetPath: '/locales/%{lng}/%{ns}.json'

  app.expose i18nOptions: options

  options.resGetPath = 'public' + options.resGetPath
  i18next.init options

  app.use (req, res, next) ->
    i18next.handle req, res, ->
      res.locals.i18n =
        t: req.i18n.t
        md: (key) -> markdownI18nCache req.i18n, key
      next()
    return

  i18next.serveClientScript app
  i18next.serveDynamicResources app

  return





