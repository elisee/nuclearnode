# NuclearNode

A node.js application template.

 * Built on [Express](http://expressjs.com/)
 * [CoffeeScript](http://coffeescript.org/) instead of JavaScript everywhere
 * [Jade](http://jade-lang.com/) for views both server-side and client-side
 * [Stylus](http://learnboost.github.io/stylus/) for clean stylesheets, with [Nib](https://github.com/visionmedia/nib) taking care of browser differences
 * [Socket.IO](http://socket.io/) for real-time communication support
 * [Grunt](https://gruntjs.com) for building all scripts, stylesheets and client-side views
 * [static-asset](https://github.com/bminer/node-static-asset) for fingerprinting static assets (ensures proper browser caching behavior)
 * [i18next-node](https://github.com/jamuhl/i18next-node) for internationalization both server-side & client-side

## Getting started

 * Duplicate ``config.coffee.template`` as ``config.coffee`` and edit the file to suit your setup
 * Start up a [redis](http://redis.io/download) server to store session data
 * Install nodemon and CoffeeScript with ```npm install -g nodemon coffee-script```
 * Run ``npm install`` to install all dependencies

### While developing

 * Run ``grunt dev`` to start a grunt watcher that will automatically rebuild assets whenever you make changes to them
 * Run ``npm run dev`` to start a development server that will automatically restart whenever you make changes to the server files

### When deploying to production

 * Run ``grunt`` to build all your assets once
 * Run ``npm start --production`` to start the server

## License

Do [whatever you want](http://www.wtfpl.net/) with this template, it's just boilerplate and I'm happy to share it. No credits or anything required.

If you improve on it, feel free to [submit pull requests](https://bitbucket.org/sparklinlabs/nuclearnode/). If you use it, feel free to [let me know](https://twitter.com/elisee).

## Future improvements

 * Look at using [asset-rack](https://github.com/techpines/asset-rack) or a similar library for serving static content
 * Add optional [Passport](http://passportjs.org/) support for authentication
