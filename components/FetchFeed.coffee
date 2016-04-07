noflo = require 'noflo'
feedparser = require 'feedparser'
request = require 'request'

# @runtime noflo-nodejs

exports.getComponent = ->
  c = new noflo.Component
  c.description = 'Fetch and parse an RSS feed'
  c.icon = 'rss'

  c.inPorts.add 'in',
    datatype: 'string'
    description: 'Feed URL'
  c.outPorts.add 'out',
    datatype: 'object'
    description: 'Item in feed'
  c.outPorts.add 'error',
    datatype: 'object'

  noflo.helpers.WirePattern c,
    in: 'in'
    out: 'out'
    async: true
    forwardGroups: true
  , (data, groups, out, callback) ->
    req = request data
    parser = new feedparser
    req.on 'error', callback
    req.on 'response', (res) ->
      if res.statusCode isnt 200
        @emit 'error', "Feed '#{data}' resulted in #{res.statusCode}"
        return
      @pipe parser
      @once 'end', ->
        callback()

    parser.on 'error', callback
    parser.on 'readable', ->
      while item = @read()
        out.send item

  c
