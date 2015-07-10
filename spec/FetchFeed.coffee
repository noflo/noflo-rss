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
      done()
  beforeEach ->
    ins = noflo.internalSocket.createSocket()
    out = noflo.internalSocket.createSocket()
    error = noflo.internalSocket.createSocket()
    c.inPorts.in.attach ins
    c.outPorts.out.attach out
    c.outPorts.error.attach error
  afterEach ->
    c.inPorts.in.detach ins
    c.outPorts.out.detach out
    c.outPorts.error.detach error
    ins = null
    out = null
    error = null

  describe 'fetching a known good feed', ->
    it 'should produce 10 items', (done) ->
      expected = 10
      groups = []
      out.on 'begingroup', (group) ->
        groups.push group
      out.on 'data', (data) ->
        chai.expect(groups).to.eql [
          1
          'http://bergie.iki.fi/blog/rss.xml'
        ]
        chai.expect(data.meta).to.be.an 'object'
        chai.expect(data.meta['rss:link']['#']).to.equal 'http://bergie.iki.fi'
        expected--
      out.on 'endgroup', (group) ->
        groups.pop()
        return if groups.length
        chai.expect(expected).to.equal 0
        done()
      error.on 'data', (data) ->
        done data

      ins.beginGroup 1
      ins.send 'http://bergie.iki.fi/blog/rss.xml'
      ins.endGroup()
