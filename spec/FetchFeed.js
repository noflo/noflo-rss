const chai = require('chai');
const noflo = require('noflo');
const path = require('path');

const baseDir = path.resolve(__dirname, '../');

describe('Feed fetching', () => {
  let c = null;
  let ins = null;
  let out = null;
  let error = null;
  before(function (done) {
    this.timeout(8000);
    const loader = new noflo.ComponentLoader(baseDir);
    loader.load('rss/FetchFeed', (err, instance) => {
      if (err) {
        done(err);
        return;
      }
      c = instance;
      ins = noflo.internalSocket.createSocket();
      c.inPorts.in.attach(ins);
      done();
    });
  });
  beforeEach(() => {
    out = noflo.internalSocket.createSocket();
    error = noflo.internalSocket.createSocket();
    c.outPorts.out.attach(out);
    c.outPorts.error.attach(error);
  });
  afterEach(() => {
    c.outPorts.out.detach(out);
    c.outPorts.error.detach(error);
    out = null;
    error = null;
  });

  describe('fetching a known RSS feed', () => it('should produce 10 items', (done) => {
    const expected = [
      '< https://bergie.iki.fi/blog/rss.xml',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      '>',
    ];
    const received = [];
    out.on('begingroup', (group) => received.push(`< ${group}`));
    out.on('data', (data) => {
      chai.expect(data.meta).to.be.an('object');
      chai.expect(data.meta['rss:link']['#']).to.equal('https://bergie.iki.fi/');
      received.push('ITEM');
    });
    out.on('endgroup', () => received.push('>'));
    out.on('disconnect', () => {
      chai.expect(received).to.eql(expected);
      done();
    });
    error.on('data', (data) => done(data));

    ins.send('https://bergie.iki.fi/blog/rss.xml');
    ins.disconnect();
  }));
  describe('fetching a known JSON feed', () => it('should produce 10 items', (done) => {
    const expected = [
      '< https://bergie.iki.fi/blog/feed.json',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      'ITEM',
      '>',
    ];
    const received = [];
    out.on('begingroup', (group) => received.push(`< ${group}`));
    out.on('data', (data) => {
      chai.expect(data.meta).to.be.an('object');
      chai.expect(data.meta.home_page_url).to.equal('https://bergie.iki.fi');
      received.push('ITEM');
    });
    out.on('endgroup', () => received.push('>'));
    out.on('disconnect', () => {
      chai.expect(received).to.eql(expected);
      done();
    });
    error.on('data', (data) => done(data));

    ins.send('https://bergie.iki.fi/blog/feed.json');
    ins.disconnect();
  }));

  describe('fetching a known missing feed', () => it('should produce an error', (done) => {
    const received = [];
    const expected = [
      'ERR',
    ];
    error.on('begingroup', (group) => received.push(`< ${group}`));
    error.on('data', (data) => {
      chai.expect(data).to.be.an('error');
      received.push('ERR');
    });
    error.on('endgroup', () => received.push('>'));
    error.on('disconnect', () => {
      chai.expect(received).to.eql(expected);
      done();
    });

    ins.send('https://bergie.iki.fi/notfound.xml');
    ins.disconnect();
  }));

  describe('fetching a non-feed URL', () => it('should produce an error', (done) => {
    const received = [];
    const expected = [
      'ERR',
    ];
    error.on('begingroup', (group) => received.push(`< ${group}`));
    error.on('data', (data) => {
      chai.expect(data).to.be.an('error');
      received.push('ERR');
    });
    error.on('endgroup', () => received.push('>'));
    error.on('disconnect', () => {
      chai.expect(received).to.eql(expected);
      done();
    });

    ins.send('https://bergie.iki.fi/blog/');
    ins.disconnect();
  }));
});
