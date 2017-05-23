noflo = require 'noflo'
feedparser = require 'feedparser'
request = require 'request'

# @runtime noflo-nodejs

handleRss = (url, res, output) ->
  parser = new feedparser
  res.pipe parser
  parser.once 'error', (err) ->
    output.sendDone err
  parser.once 'readable', ->
    output.send
      out: new noflo.IP 'openBracket', url
  parser.on 'readable', ->
    while item = @read()
      output.send
        out: item
  parser.on 'end', ->
    output.send
      out: new noflo.IP 'closeBracket', url
    output.done()

handleJson = (url, res, output) ->
  data = ''
  res.on 'data', (chunk) ->
    data += chunk
  res.on 'end', ->
    try
      feed = JSON.parse data
    catch e
      return output.done e
    unless feed.items?.length
      return output.done new Error "Invalid JSON feed for #{url}"
    output.send
      out: new noflo.IP 'openBracket', url
    feedMeta = {}
    for key, val of feed
      continue if key is 'items'
      feedMeta[key] = val
    for item in feed.items
      item.meta = feedMeta
      output.send
        out: item
    output.send
      out: new noflo.IP 'closeBracket', url
    output.done()

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
    req.once 'error', (err) ->
      output.sendDone err
    req.on 'response', (res) ->
      if res.statusCode isnt 200
        @emit 'error', new Error "Feed '#{data}' resulted in #{res.statusCode}"
        return
      if res.headers['content-type']?.indexOf('application/json') isnt -1
        # JSON Feed, skip parsing
        handleJson data, @, output
        return
      handleRss data, @, output
