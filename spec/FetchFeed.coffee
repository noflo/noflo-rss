chai = require 'chai'
noflo = require 'noflo'
path = require 'path'
baseDir = path.resolve __dirname, '../'

describe 'Feed fetching', ->
  c = null
  ins = null
  out = null
  error = null
  before (done) ->
    @timeout 8000
    loader = new noflo.ComponentLoader baseDir
    loader.load 'rss/FetchFeed', (err, instance) ->
      return done err if err
      c = instance
      ins = noflo.internalSocket.createSocket()
      c.inPorts.in.attach ins
      done()
  beforeEach ->
    out = noflo.internalSocket.createSocket()
    error = noflo.internalSocket.createSocket()
    c.outPorts.out.attach out
    c.outPorts.error.attach error
  afterEach ->
    c.outPorts.out.detach out
    c.outPorts.error.detach error
    out = null
    error = null

  describe 'fetching a known RSS feed', ->
    it 'should produce 10 items', (done) ->
      expected = [
        '< https://bergie.iki.fi/blog/rss.xml'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        '>'
      ]
      received = []
      out.on 'begingroup', (group) ->
        received.push "< #{group}"
      out.on 'data', (data) ->
        chai.expect(data.meta).to.be.an 'object'
        chai.expect(data.meta['rss:link']['#']).to.equal 'https://bergie.iki.fi/'
        received.push 'ITEM'
      out.on 'endgroup', (group) ->
        received.push '>'
      out.on 'disconnect', ->
        chai.expect(received).to.eql expected
        done()
      error.on 'data', (data) ->
        done data

      ins.send 'https://bergie.iki.fi/blog/rss.xml'
      ins.disconnect()
  describe 'fetching a known JSON feed', ->
    it 'should produce 10 items', (done) ->
      expected = [
        '< https://bergie.iki.fi/blog/feed.json'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        'ITEM'
        '>'
      ]
      received = []
      out.on 'begingroup', (group) ->
        received.push "< #{group}"
      out.on 'data', (data) ->
        chai.expect(data.meta).to.be.an 'object'
        chai.expect(data.meta['home_page_url']).to.equal 'https://bergie.iki.fi'
        received.push 'ITEM'
      out.on 'endgroup', (group) ->
        received.push '>'
      out.on 'disconnect', ->
        chai.expect(received).to.eql expected
        done()
      error.on 'data', (data) ->
        done data

      ins.send 'https://bergie.iki.fi/blog/feed.json'
      ins.disconnect()

  describe 'fetching a known missing feed', ->
    it 'should produce an error', (done) ->
      received = []
      expected = [
        'ERR'
      ]
      error.on 'begingroup', (group) ->
        received.push "< #{group}"
      error.on 'data', (data) ->
        chai.expect(data).to.be.an 'error'
        received.push 'ERR'
      error.on 'endgroup', (group) ->
        received.push '>'
      error.on 'disconnect', ->
        chai.expect(received).to.eql expected
        done()

      ins.send 'https://bergie.iki.fi/notfound.xml'
      ins.disconnect()

  describe 'fetching a non-feed URL', ->
    it 'should produce an error', (done) ->
      received = []
      expected = [
        'ERR'
      ]
      error.on 'begingroup', (group) ->
        received.push "< #{group}"
      error.on 'data', (data) ->
        chai.expect(data).to.be.an 'error'
        received.push 'ERR'
      error.on 'endgroup', (group) ->
        received.push '>'
      error.on 'disconnect', ->
        chai.expect(received).to.eql expected
        done()

      ins.send 'https://bergie.iki.fi/blog/'
      ins.disconnect()
