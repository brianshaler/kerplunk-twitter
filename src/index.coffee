_ = require 'lodash'
async = require 'async'
Promise = require 'when'

SetupModule = require './twitter/setup'
APIModule = require './twitter/api'

module.exports = (System) ->
  API = APIModule System
  Setup = SetupModule System, API

  Identity = System.getModel 'Identity'
  ActivityItem = System.getModel 'ActivityItem'

  getStatus = (req, res, next) ->
    tweetId = req.params.id
    guid = "twitter-#{tweetId}"
    ActivityItem.findOne {guid: guid}, (err, item) ->
      throw err if err
      if item
        console.log 'found item in DB'
        item = _.clone item.toObject()
        item.fromCache = true
        return res.send item
      API.getTweetById tweetId, (err, activityItem) ->
        throw err if err
        console.log 'fetched item'
        activityItem = _.clone activityItem.toObject()
        activityItem.fromCache = false
        res.send activityItem

  homeTimeline = (req, res, next) ->
    API.timeline (err, items) ->
      throw err if err
      res.send items

  userTimeline = (req, res, next) ->
    API.userTimeline req.params.id, (err, items) ->
      throw err if err
      res.send items

  globals:
    public:
      nav:
        Admin:
          'Social Networks':
            Twitter:
              'App Settings': '/admin/twitter/app'
              'Connect Account': '/admin/twitter/connect'
      editStreamConditionOptions:
        isTweetTrue:
          description: 'tweets only'
          where:
            platform: 'twitter'
        isTweetFalse:
          description: 'no tweets'
          where:
            platform:
              '$ne': 'twitter'
      activityItem:
        icons:
          twitter: '/plugins/kerplunk-twitter/images/Twitter_logo_blue.png'

  routes:
    admin:
      '/admin/twitter/:step': 'setup'
      '/admin/twitter': 'gotoSetup'
      '/admin/twitter/oauth': 'oauth'
      '/admin/twitter/auth': 'auth'
      '/admin/twitter/timeline': 'timeline'
      '/admin/twitter/statuses/show/:id': 'getStatus'
      '/admin/twitter/statuses/home_timeline': 'homeTimeline'
      '/admin/twitter/statuses/user_timeline/:id': 'userTimeline'
      '/admin/me': 'me'

  handlers:
    setup: Setup.setup
    gotoSetup: (req, res, next) ->
      res.redirect '/admin/twitter/app'
    oauth: Setup.oauth
    auth: Setup.auth
    timeline: (req, res, next) ->
      API.isSetup (err, isSetup) ->
        throw err if err
        if isSetup
          API.timeline (err) ->
            return res.send err if err
            res.send 'Done.'
        else
          res.send 'Not set up.'
    getStatus: getStatus
    homeTimeline: homeTimeline
    userTimeline: userTimeline
    me: (req, res, next) ->
      Identity.getMe (err, me) ->
        return next err if err
        res.send me

  jobs:
    timeline:
      frequency: 120
      task: (finished) ->
        Promise.promise (resolve, reject) ->
          API.isSetup (err, isSetup) ->
            return reject err if err
            resolve isSetup
        .then (isSetup) ->
          if isSetup == true
            API.timeline (err) ->
              console.log "Twitter API.timeline" if err
              console.error err if err
