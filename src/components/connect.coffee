React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    DOM.div
      className: 'admin-panel'
    ,
      DOM.p null,
        'We will now authenticate your user account to the app...'
      DOM.p null,
        DOM.a
          href: '/twitter/oauth'
        , 'Click here to authenticate'
      if @props.settings?.twitter?.isSetup
        DOM.p null,
          DOM.strong null, 'Your account has been connected!'
