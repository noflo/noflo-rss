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

  c.process (input, output) ->
    return unless input.hasData 'in'
    data = input.getData 'in'
    req = request data
    parser = new feedparser
    req.once 'error', (err) ->
      output.sendDone err
    req.on 'response', (res) ->
      if res.statusCode isnt 200
        @emit 'error', new Error "Feed '#{data}' resulted in #{res.statusCode}"
        return
      @pipe parser
    parser.once 'error', (err) ->
      output.sendDone err
    parser.on 'readable', ->
      while item = @read()
        output.send
          out: item
    parser.on 'end', ->
      output.done()
