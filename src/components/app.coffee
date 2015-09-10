React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    DOM.section
      className: 'content admin-panel'
    ,
      DOM.h1 {}, 'Twitter Configuration'
      DOM.p null,
        'Copy the details from your Twitter App, which you can find or create at '
        DOM.a
          href: 'https://dev.twitter.com/apps'
          target: '_blank'
        , 'https://dev.twitter.com/apps'
      DOM.p null,
        DOM.form
          method: 'post'
          action: '/admin/twitter/app'
        ,
          DOM.table null,
            DOM.tr null,
              DOM.td null,
                DOM.strong null, 'Consumer Key:'
              DOM.td null,
                DOM.input
                  name: 'settings[twitter][consumer_key]'
                  defaultValue: @props.settings?.twitter?.consumer_key
                , ''
            DOM.tr null,
              DOM.td null,
                DOM.strong null, 'Consumer Secret:'
              DOM.td null,
                DOM.input
                  name: 'settings[twitter][consumer_secret]'
                  defaultValue: @props.settings?.twitter?.consumer_secret
                , ''
            DOM.tr null,
              DOM.td null,
                DOM.strong null, 'Callback URL:'
              DOM.td null,
                DOM.input
                  name: 'settings[twitter][callback_url]'
                  defaultValue: @props.settings?.twitter?.callback_url
                , ''
            DOM.tr null,
              DOM.td null, ''
              DOM.td null,
                DOM.input
                  type: 'submit'
                  value: 'Save & Next'
                , ''
