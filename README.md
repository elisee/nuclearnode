# NuclearNode

NuclearNode is a Node.js application template for building cooperative
applications and multiplayer games around a [NuclearHub](https://bitbucket.org/sparklinlabs/nuclearhub).

A NuclearHub allows people to log in to various NuclearNode applications or
games using a shared account stored on the hub itself and have named channels to
work in groups or play with friends, privately or publicly.

## Technology

 * Built on [Express](http://expressjs.com/)
 * [CoffeeScript](http://coffeescript.org/) instead of JavaScript everywhere
 * [Jade](http://jade-lang.com/) for server-side views & client-side templates
 * [Stylus](http://learnboost.github.io/stylus/) for clean stylesheets, with [Nib](https://github.com/visionmedia/nib) taking care of browser differences
 * Uses [passport-nuclearhub](https://github.com/elisee/passport-nuclearhub) to log in existing users even across domain names
 * [Socket.IO](http://socket.io/) for real-time communication support
 * [Grunt](https://gruntjs.com) for building all scripts, stylesheets and client-side templates
 * [static-asset](https://github.com/bminer/node-static-asset) for fingerprinting static assets (ensures proper browser caching behavior)
 * [nuclear-i18n](https://github.com/elisee/nuclear-i18n) for [i18next](https://github.com/jamuhl/i18next-node)-based internationalization

## Getting started

 * Duplicate ``config.coffee.template`` as ``config.coffee`` and edit the file to suit your setup
 * Start up a [redis](http://redis.io/download) server to store session data
 * Install grunt, nodemon and CoffeeScript with ```npm install -g grunt-cli nodemon coffee-script```
 * Run ``npm install`` to install all dependencies

To develop your app or game, you'll want to edit the following files:

 * ``views/main.jade`` for the main application view
 * ``assets/coffeescripts/main.coffee`` for client-side application logic
 * ``assets/stylesheets/main.styl`` for styling
 * ``lib/ChannelLogic.coffee`` for server-side application logic
 * ``assets/locales/LANGUAGE/common.cson`` to add localized strings to your app

### While developing

 * Run ``grunt dev`` to start a grunt watcher that will automatically rebuild assets whenever you make changes to them
 * Run ``npm run dev`` to start a development server that will automatically restart whenever you make changes to the server files

### When deploying to production

 * Run ``grunt`` to build all your assets once
 * Run ``npm start --production`` to start the server

## License

Do [whatever you want](http://www.wtfpl.net/). A credit to Elisée Maurer as
the original author is appreciated but not required.

If you improve on NuclearNode, please [submit pull requests](https://bitbucket.org/sparklinlabs/nuclearnode/).
If you use it, [I'd love to know](https://twitter.com/elisee).
