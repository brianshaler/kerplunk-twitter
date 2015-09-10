async = require "async"
twitterApi = require "ntwitter"

PLATFORM = "twitter"

module.exports = (System) ->
  Identity = System.getModel 'Identity'
  ActivityItem = System.getModel 'ActivityItem'

  API =
    prep: (next) ->
      System.getSettings (err, settings) ->
        return next err if err
        twitter = API.getTwitter settings, settings.access_token_key, settings.access_token_secret
        next null, settings, twitter

    getTwitter: (settings, access_token_key, access_token_secret) ->
      twit = new twitterApi
        consumer_key: settings.consumer_key
        consumer_secret: settings.consumer_secret
        access_token_key: access_token_key
        access_token_secret: access_token_secret
      twit

    isSetup: (next) ->
      System.getSettings (err, settings) ->
        isSetup = false
        if settings?.access_token_key and settings.access_token_secret
          isSetup = true
        next err, isSetup

    timeline: (next) ->
      #console.log "fetching twitter timeline"
      API.prep (err, settings, twitter) ->
        return next err if err

        sinceId = settings.timelineSinceId ? -1
        params =
          count: 100
          include_entities: true
        if sinceId and sinceId != -1
          params.since_id = sinceId
        #console.log "params", params

        twitter.getHomeTimeline params, (err, tweets) ->
          console.error err if err
          return next err if err
          if !tweets or tweets.length == 0 or !tweets[0] or !tweets[0].hasOwnProperty "id_str"
            #console.log "No tweets.."
            return next null, []

          sinceId = tweets[0].id_str

          settings.timelineSinceId = sinceId
          System.updateSettings settings, (err) ->
            console.error err if err
            # do nothing upon save completion

          async.map tweets, API.processTweet, (err, data) ->
            console.log "Timeline processing complete!"
            next err, data

    userTimeline: (userId, next) ->
      console.log "fetching user #{userId} timeline"
      API.prep (err, settings, twitter) ->
        return next err if err

        sinceId = -1
        params =
          count: 20
          include_entities: true
          user_id: userId

        ActivityItem.find()
        .sort({"postedAt": -1})
        .findOne (err, item) ->
          if item?.data?.id_str and 1==2
            sinceId = item.data.id_str
          if sinceId != -1
            params.since_id = sinceId

          console.log "getting #{userId}'s tweets"
          twitter.getUserTimeline params, (err, tweets) ->
            #console.log "received #{tweets.length} tweets" if tweets?
            console.error err if err
            return next err if err
            if !tweets or tweets.length == 0 or !tweets[0] or !tweets[0].hasOwnProperty "id_str"
              #console.log "No tweets.."
              return next null, []

            async.map tweets, API.processTweet, (err, data) ->
              #console.log "Timeline processing complete!"
              next err, data

    processTweet: (tweet, next) ->
      do (tweet, next) ->
        #console.log "Processing tweet: "+tweet.text.substring(0, 50)

        lng = lat = 0
        if tweet.coordinates and tweet.coordinates.type == "Point" and tweet.coordinates.coordinates
          lng = parseFloat tweet.coordinates.coordinates[0]
          lat = parseFloat tweet.coordinates.coordinates[1]
        loc = null
        if lng != 0 or lat != 0
          loc = [lng, lat]

        user = tweet.user
        user.platformId = user.id_str
        user.firstName = user.name.split(' ').slice(0,-1).join ' '
        unless user.firstName == user.name
          user.lastName = user.name.split(' ').slice(-1).join ' '
        user.fullName = user.name
        user.nickName = user.screen_name
        user.profileUrl = "https://twitter.com/#{user.screen_name}"

        data =
          identity:
            guid: ["#{PLATFORM}-#{tweet.user.id_str}"]
            platform: [PLATFORM]
            firstName: user.firstName
            lastName: user.lastName
            fullName: user.fullName
            nickName: user.nickName
            photo: [
              {url: tweet.user.profile_image_url_https}
            ]
            data:
              twitter: user
          item:
            guid: "#{PLATFORM}-#{tweet.id_str}"
            platformId: tweet.id_str
            platform: PLATFORM
            location: loc
            message: tweet.text
            postedAt: new Date tweet.created_at
            data: tweet

        # console.log 'getOrCreate', data.item.guid
        ActivityItem.getOrCreate data, (err, activityItem, identity) ->
          return next err if err

          if tweet.retweeted_status?.text
            API.processTweet tweet.retweeted_status, (err, retweeted, retweetedIdentity) ->
              if err or !retweeted
                return next err, retweeted, retweetedIdentity

              found = false
              retweeted.activity = [] unless retweeted.activity?.length > 0
              for act in retweeted.activity
                if act.identity == identity._id and act.action == "retweet"
                  found = true
              if found
                next err, retweeted, retweetedIdentity
              else
                activityItem.message = "Retweeted"
                activityItem.activityOf = retweeted._id
                System.do 'activityItem.save', activityItem
                .done ->
                  retweeted.activity.push activityItem._id

                  retweeted.save (err) ->
                    console.log '156', err if err
                    next err, retweeted, retweetedIdentity
                , (err) ->
                  console.log '159', err.stack
                  next err
            return # API goes async then calls next()

          identity.attributes = {} if !identity.attributes?
          identity.attributes.twitterFavoritesCount = tweet.user.favourites_count
          if !identity.attributes.twitterFavoritesCached
            identity.attributes.twitterFavoritesCached = 0

          if tweet.user.following == true
            identity.attributes.isFriend = true
          else if !identity.attributes.isFriend and tweet.user.following == false
            identity.attributes.isFriend = false

          if tweet.user.hasOwnProperty("following")
            identity.attributes.isFriend = if tweet.user.following then true else false

          photoFound = false
          for photo in identity.photo
            if photo.url == tweet.user.profile_image_url_https
              photoFound = true
          if !photoFound
            identity.photo.push
              url: tweet.user.profile_image_url_https
          identity.updatedAt = new Date()

          identity.markModified "attributes"
          identity.save (err) ->
            throw err if err

            activityItem.attributes = {} if !activityItem.attributes?
            activityItem.attributes.isFriend = identity.attributes.isFriend

            entities = tweet.extended_entities ? tweet.entities
            #console.log entities
            if entities?.media?.length > 0
              entities.media.forEach (media) ->
                image =
                  type: media.type
                  sizes: [{url: media.media_url, width: media.sizes.large.w, height: media.sizes.large.h}]
                activityItem.media = [image]

            activityItem.markModified 'attributes'
            System.do 'activityItem.save', activityItem
            .done ->
              if activityItem.data.in_reply_to_status_id_str?.length > 0
                API.getTweetById activityItem.data.in_reply_to_status_id_str, (tweetErr, parent) ->
                  if tweetErr or !parent
                    console.error tweetErr if tweetErr
                    console.log "failed to fetch replied-to tweet! #{activityItem.data.in_reply_to_status_id_str}"
                    return next null, activityItem, identity
                  activityItem.activityOf = parent._id
                  System.do 'activityItem.save', activityItem
                  .catch (err) ->
                    console.log 'err', err.stack
                    true
                  .then ->
                    next null, activityItem, identity
              else
                next null, activityItem, identity
              return
            , (err) ->
              console.log '232', err.stack
              next err

    getTweetById: (tweetId, next) ->
      guid = "#{PLATFORM}-#{tweetId}"

      ActivityItem.findOne {guid: guid}, (err, item) ->
        if err
          return next err

        if item and item.guid == guid
          next null, item
        else
          API.prep (err, settings, twitter) ->
            return next err if err
            twitter = API.getTwitter settings, settings.access_token_key, settings.access_token_secret
            twitter.showStatus tweetId, (err, tweet) ->
              if tweet and tweet.id_str
                API.processTweet tweet, (err, activityItem) ->
                  if err
                    return next err

                  next null, activityItem
              else
                #console.log "Couldn't fetch tweet"
                #console.log tweet, tweetId
                next "Couldn't fetch tweet.."
