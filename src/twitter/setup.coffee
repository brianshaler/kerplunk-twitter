url = require 'url'

APIModule = require './api'

PLATFORM = 'twitter'
dirName = String(__dirname).replace /\/lib$/, ''

Setup = (System, API) ->
  Identity = System.getModel 'Identity'

  setupApp = (req, res, next) ->
    System.getSettings (err, settings) ->
      return next err if err
      if req.body?.settings?.twitter
        # Process form

        for k, v of req.body.settings.twitter
          settings[k] = v

        System.updateSettings settings, (err) ->
          return next err if err

          # Done with this step. Continue!
          res.redirect '/admin/twitter/connect'
      else
        # Show the page for this step
        console.log 'show settings', settings
        res.render 'app',
          settings:
            twitter: settings

  setupConnect = (req, res, next) ->
    System.getSettings (err, settings) ->
      isSetup = false
      if settings.access_token_key and settings.access_token_secret
        isSetup = true

      # Show the page for this step
      res.render 'connect',
        settings:
          twitter:
            isSetup: isSetup

  setup: (req, res, next) ->
    step = req.params.step
    if step == "app" or step == "" or !step # Default is Step 1: /admin/twitter/app
      setupApp req, res, next
    else if step == "connect"
      setupConnect req, res, next
    else
      next()

  oauth: (req, res, next) ->
    System.getSettings (err, settings) ->
      t = API.getTwitter settings
      auther = t.login '/admin/twitter/oauth', '/admin/twitter/auth'
      auther req, res, next

  auth: (req, res, next) ->
    # THIS IS ANNOYING!
    # When the user authenticates, the Twitter module redirects /admin/twitter/auth?[keys_here] to /admin/twitter/auth with the keys in a cookie
    # The cookie doesn't play nice with Express's cookieParser, so you have to extract the cookie via the internal cookie() method
    tmpTwitter = API.getTwitter
      consumer_key: ''
      consumer_secret: ''
    twitterCredentials = tmpTwitter.cookie req

    access_token_key = twitterCredentials.access_token_key
    access_token_secret = twitterCredentials.access_token_secret
    twitterName = twitterCredentials.screen_name

    # Save keys to the 'twitter' DOM.option in the Settings collection
    System.getSettings (err, settings) ->
      t = API.getTwitter settings, access_token_key, access_token_secret
      t.verifyCredentials (err, data) ->
        if err?.statusCode == 401
          # unauthorized
          settings.access_token_key = null
          delete settings.access_token_key
          settings.access_token_secret = null
          delete settings.access_token_secret
          System.updateSettings settings, ->
            console.log 'Redirecting to /admin/twitter/oauth'
            #res.redirect "/admin/twitter/oauth"
            res.send 'redirect to /admin/twitter/oauth'
          return
        return next err if err
        t.showUser twitterName, (err, data) ->
          return next err if err
          if data
            if data.length > 0 and data[0]
              data = data[0]
            settings.access_token_key = access_token_key
            settings.access_token_secret = access_token_secret
            identity =
              guid: "#{PLATFORM}-#{data.id_str}"
              platform: PLATFORM
              platformId: data.id_str
              userName: data.screen_name
              displayName: "#{data.name} (@#{data.screen_name})"
              url: "https://twitter.com/#{data.screen_name}"
              photo: [
                {url: data.profile_image_url_https}
              ]
              data:
                twitter: data
            Identity.getMe (err, me) ->
              return next err if err
              Identity.getOrCreate identity, (err, myTwitter) ->
                return next err if err
                console.log "linking #{me._id} to #{myTwitter._id}"
                me.link myTwitter, (err) ->
                  return next err if err
                  System.updateSettings settings, (err) ->
                    return next err if err
                    API.timeline -> console.log "Initial timeline fetched"
                    return res.redirect "/admin/twitter/connect"
                    #return res.send "Twitter successfully connected. <a href=\"/admin/setup\">Continue setup?</a>"
          else
            return res.send "Failed to retrieve Twitter details."
          #res.send(data);

module.exports = Setup
