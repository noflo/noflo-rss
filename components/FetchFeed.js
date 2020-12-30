const noflo = require('noflo');
const Feedparser = require('feedparser');
const request = require('request');

// @runtime noflo-nodejs

function handleRss(url, res, output) {
  const parser = new Feedparser();
  res.pipe(parser);
  parser.once('error', (err) => output.sendDone(err));
  parser.once('readable', () => output.send({
    out: new noflo.IP('openBracket', url),
  }));
  parser.on('readable', function () {
    let item;
    const result = [];
    while (item = this.read()) { // eslint-disable-line no-cond-assign
      result.push(output.send({ out: item }));
    }
    return result;
  });
  parser.on('end', () => {
    output.send({ out: new noflo.IP('closeBracket', url) });
    output.done();
  });
}

function handleJson(url, res, output) {
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  return res.on('end', () => {
    let feed;
    try {
      feed = JSON.parse(data);
    } catch (e) {
      output.done(e);
      return;
    }
    if (!(feed.items != null ? feed.items.length : undefined)) {
      output.done(new Error(`Invalid JSON feed for ${url}`));
      return;
    }
    output.send({ out: new noflo.IP('openBracket', url) });
    const feedMeta = {};
    Object.keys(feed).forEach((key) => {
      const val = feed[key];
      if (key === 'items') { return; }
      feedMeta[key] = val;
    });
    feed.items.forEach((item) => {
      output.send({
        out: {
          ...item,
          meta: feedMeta,
        },
      });
    });
    output.send({ out: new noflo.IP('closeBracket', url) });
    output.done();
  });
}

exports.getComponent = () => {
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
    req.once('error', (err) => {
      output.sendDone(err);
    });
    req.on('response', function (res) {
      if (res.statusCode !== 200) {
        output.done(new Error(`Feed '${data}' resulted in ${res.statusCode}`));
        return;
      }
      if ((res.headers['content-type'] != null ? res.headers['content-type'].indexOf('application/json') : undefined) !== -1) {
        // JSON Feed, skip parsing
        handleJson(data, this, output);
        return;
      }
      handleRss(data, this, output);
    });
  });
};
