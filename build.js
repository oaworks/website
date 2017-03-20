
// build static files to serve

// look for top level index and header and footer
// go through content folder and build a serve folder - throw away all that was in there before, rebuild from scratch
// for every file get the top level index and header and footer and wrap them round it
// get any referenced js files and minify and bundle them

// still allow nginx to serve any files it does find in the folder directly

// what about autoload of following content? just as current, via the nginx routes to /content?


var fs = require('fs');

var tags = function(tag,content) {
  var re = new RegExp("<" + tag + ".*?>","gi");
  var res = [];
  var match;
  while (match = re.exec(content)) {
    var str = match[2];
    str = str.replace(/[ ]{0,1}=[ ]{0,1}/gi,'=');
    var parts = str.split(' ');
    var obj = {};
    for ( var i in parts ) {
      var se = parts.split('=');
      if (se.length === 2) {
        var clean = se[1];
        if ( clean.indexOf('"') === 0 || clean.indexOf("'") === 0 ) clean = clean.substring(1,clean.length);
        if ( clean.substring(clean.length-1,1) === '"' || clean.substring(clean.length-1,1) === "'" ) clean = clean.substring(1,clean.length-1);
        obj[se[0]] = clean;
      } else {
        if (obj.tag !== undefined) {
          obj.tag = se[0];
        } else {
          if (obj.vals === undefined) obj.vals = [];
          obj.vals.push(se[0]);
        }
      }
    }
    res.push(match[2]);
  }
  console.log("tags");
  console.log(res);
  return res;
}

var walk = function(dir, done) {
  var results = [];
  fs.readdir(dir, function(err, list) {
    if (err) return done(err);
    var i = 0;
    (function next() {
      var file = list[i++];
      if (!file) return done(null, results);
      file = dir + '/' + file;
      fs.stat(file, function(err, stat) {
        if (stat && stat.isDirectory()) {
          walk(file, function(err, res) {
            results = results.concat(res);
            next();
          });
        } else {
          results.push(file);
          next();
        }
      });
    })();
  });
};

var deleteFolderRecursive = function(path) {
  if ( fs.existsSync(path) ) {
    fs.readdirSync(path).forEach(function(file,index) {
      var curPath = path + "/" + file;
      if (fs.lstatSync(curPath).isDirectory()) { // recurse
        deleteFolderRecursive(curPath);
      } else { // delete file
        console.log("Deleting " + curPath);
        fs.unlinkSync(curPath);
      }
    });
    console.log("Deleting " + path);
    fs.rmdirSync(path);
  }
};
deleteFolderRecursive('./serve');
fs.mkdirSync('./serve');

var jshash, csshash;
var js = [];
var css = [];
/*walk('./static', function(err, results) {
  var other = [];
  for ( var r in results ) {
    var fl = results[r];
    if ( fl.indexOf('.js') !== -1 ) {
      js.push(fl);
    } else if ( fl.indexOf('.css') !== -1 ) {
      css.push(fl);
    } else {
      other.push(fl);
    }
  }
  console.log(js);
  console.log(css);
  var uglyjs, uglycss;
  var crypto = require('crypto');
  fs.mkdirSync('./serve/static');
  // gz compress them too?
  if (js.length) {
    var uglify = require("uglify-js");
    uglyjs = uglify.minify(js);
    jshash = crypto.createHash('md5').update(uglyjs.code).digest("hex");
    fs.writeFileSync('./serve/static/' + jshash + '.min.js', uglyjs.code);
  }
  if (css.length) {
    var uglifycss = require('uglifycss');
    uglycss = uglifycss.processFiles(css);
    csshash = crypto.createHash('md5').update(uglycss).digest("hex");
    fs.writeFileSync('./serve/static/' + csshash + '.min.css', uglycss);
  }*/
  /*if (other.length) { // nothing to do with other things yet, and nginx config serves them fine
    for ( var o in other ) {
      fs.createReadStream(other[o]).pipe(fs.createWriteStream(other[o].replace('/static/','/serve/static/')));
    }
  }*/
//});

var handlebars = require('handlebars');

var templates = [];
walk('./templates', function(err, results) {
  for ( var r in results ) {
    var fl = results[r];
    var part = fs.readFileSync(fl).toString();
    var fln = fl.replace('./templates/','').split('.')[0];
    templates.push(fln);
    handlebars.registerPartial(fln,part);
  }

  walk('./content', function(err, results) {
    if (err) throw err;

    // sort the results in some way?
    for ( var tr in results ) templates.push(results[tr].replace('./content/',''));
    console.log("Templates:");
    console.log(templates);

    for ( var r in results ) {
      // settings in files do not do anything yet...
      var settings = {};
      settings.head = undefined;
      settings.header = undefined;
      settings.footer = undefined;
      settings.title = undefined;
      settings.prev = undefined;
      settings.next = undefined;
      settings.append = undefined;
      settings.from = undefined;
      settings.draft = undefined;
      settings.collection = undefined;
      settings.scroll = undefined;
      settings.date = undefined;
      settings.order = undefined;
      settings.tags = undefined;
      settings.context = {};
      try { settings.context = require('context.json'); } catch(err) {}

      var fl = results[r];
      var content = fs.readFileSync(fl).toString();

      if (content.indexOf('---') !== -1) {
        var pts = content.split('---');
        if (pts.length === 3) {
          var sets = pts[1];
          // parse sets for settings info
          content = pts[2];
        }
      }

      if (settings.header !== false && content.indexOf('<header') === -1) {
        if (settings.header !== undefined) {
          content = '{{> ' + settings.header + ' }}' + '\n\n' + content;
        } else if (templates.indexOf('header') !== -1) {
          content = '{{> header }}' + '\n\n' + content;
        }
      }

      if (settings.footer !== false && content.indexOf('<footer') === -1) {
        if (settings.footer !== undefined) {
          content = content + '\n\n{{> ' + settings.footer + ' }}\n\n';
        } else if (templates.indexOf('footer') !== -1) {
          content = content + '\n\n{{> footer }}\n\n';
        }
      }

      // look for any <extrahead></extrahead> section in the content - extract it
      var extrahead = undefined;
      if ( content.indexOf('<extrahead>') !== -1 ) {
        var pa = content.split('</extrahead>');
        extrahead = pa[0].replace('<extrahead>','');
        content = pa[1];
      }

      if (content.indexOf('<body') === -1) content = '<body>\n' + content + '\n</body>';

      if (settings.head !== false && content.indexOf('<head') === -1) {
        if (settings.head !== undefined) {
          content = '{{> ' + settings.head + ' }}' + '\n\n' + content;
        } else if (templates.indexOf('head') !== -1) {
          content = '{{> head }}' + '\n\n' + content;
        }
      }

      // make all content files available as handlebars partials too?

      if (templates.indexOf('mandatory') !== -1) content += '{{> mandatory }}';

      var template = handlebars.compile(content);
      content = template(settings.context);

      var marked;
      if ( fl.indexOf('.md') !== -1) {
        marked = require('marked');
        content = marked(content);
      } else if ( content.indexOf('<markdown>') !== -1 ) {
        var nc = '';
        var cp = content.split('<markdown>');
        for ( var a in cp ) {
          if (a === 0) {
            nc += cp[a];
          } else {
            var pts = cp[a].split('</markdown>');
            marked = require('marked');
            nc += marked(pts[0]) + pts[1];
          }
        }
        content = nc;      
      }

      // insert the calls to the necessary js and css, and any extra head data provided in the page itself
      if (content.indexOf('<head') === -1) content = '\n<head>\n</head>\n\n' + content;
      if (csshash) {
        content = content.replace('</head>','<link rel="stylesheet" href="/static/' + csshash + '.min.css">\n</head>');
        for ( var c in css ) {
          var cr = '<link.*?' + css[c].replace('./','') + '.*?>';
          var cre = new RegExp(cr,"g");
          content = content.replace(cre,'');
        }
      }
      if (jshash) {
        content = content.replace('</head>','<script src="/static/' + jshash + '.min.js"></script>\n</head>');
        for ( var j in js ) {
          var jr = '<script.*?' + js[j].replace('./','') + '.*?<\/script>';
          var jre = new RegExp(jr,"g");
          content = content.replace(jre,'');
        }
      }
      if (extrahead) content = content.replace('</head>',extrahead + '\n</head>');

      // ensure there is a title on the page meta, and append | where title is provided    

      // now can run plugins on content if necessary, or just keep simple - one useful one could be lunr.js

      var open, close;
      try { open = fs.readFileSync('./templates/open.html').toString(); } catch(err) { open = '<!DOCTYPE html><html dir="ltr" lang="en">'; }
      try { close = fs.readFileSync('./templates/close.html').toString(); } catch(err) { close = '\n</html>'; }
      if ( content.indexOf('<html') === -1 ) content = open + content;
      if ( content.indexOf('</html') === -1 ) content = content + close;

      var dcp = fl.replace('./content/','').split('/');
      var dc = './serve';
      for ( var i = 0; i < dcp.length-1; i++ ) {
        dc += '/' + dcp[i];
        if (!fs.existsSync(dc)) fs.mkdirSync(dc);
      }
      fs.writeFileSync(fl.replace('./content/','./serve/').replace('.md','').replace('.html','')+'.html',content);

    }

    console.log("Files");
    console.log(results);
  });

});







