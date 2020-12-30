/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const noflo = require('noflo');
const feedparser = require('feedparser');
const request = require('request');

// @runtime noflo-nodejs

const handleRss = function (url, res, output) {
  const parser = new feedparser();
  res.pipe(parser);
  parser.once('error', (err) => output.sendDone(err));
  parser.once('readable', () => output.send({ out: new noflo.IP('openBracket', url) }));
  parser.on('readable', function () {
    return (() => {
      let item;
      const result = [];
      while ((item = this.read())) {
        result.push(output.send({ out: item }));
      }
      return result;
    })();
  });
  return parser.on('end', () => {
    output.send({ out: new noflo.IP('closeBracket', url) });
    return output.done();
  });
};

const handleJson = function (url, res, output) {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  return res.on('end', () => {
    let feed;
    try {
      feed = JSON.parse(data);
    } catch (e) {
      return output.done(e);
    }
    if (!(feed.items != null ? feed.items.length : undefined)) {
      return output.done(new Error(`Invalid JSON feed for ${url}`));
    }
    output.send({ out: new noflo.IP('openBracket', url) });
    const feedMeta = {};
    for (const key in feed) {
      const val = feed[key];
      if (key === 'items') { continue; }
      feedMeta[key] = val;
    }
    for (const item of Array.from(feed.items)) {
      item.meta = feedMeta;
      output.send({ out: item });
    }
    output.send({ out: new noflo.IP('closeBracket', url) });
    return output.done();
  });
};

exports.getComponent = function () {
  const c = new noflo.Component();
  c.description = 'Fetch and parse an RSS feed';
  c.icon = 'rss';

  c.inPorts.add('in', {
    datatype: 'string',
    description: 'Feed URL',
  });
  c.outPorts.add('out', {
    datatype: 'object',
    description: 'Item in feed',
  });
  c.outPorts.add('error',
    { datatype: 'object' });

  return c.process((input, output) => {
    if (!input.hasData('in')) { return; }
    const data = input.getData('in');
    const req = request(data);
    req.once('error', (err) => output.sendDone(err));
    return req.on('response', function (res) {
      if (res.statusCode !== 200) {
        this.emit('error', new Error(`Feed '${data}' resulted in ${res.statusCode}`));
        return;
      }
      if ((res.headers['content-type'] != null ? res.headers['content-type'].indexOf('application/json') : undefined) !== -1) {
        // JSON Feed, skip parsing
        handleJson(data, this, output);
        return;
      }
      return handleRss(data, this, output);
    });
  });
};
