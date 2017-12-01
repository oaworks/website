/**********************************

Holder

created by Mark MacGillivray - mark@cottagelabs.com
MIT
January 2017

VERSION 0.3.0

**********************************/

(function($) {
  $.fn.holder = function(options) {

    // Every function of holder is an option. Look below to see all default functions. Any can be overridden by providing 
    // an alternative function in the options.
    
    // to add functionality to any default function, e.g. to run something after it finishes, the normal jquery addition 
    // of functions on done can work, on either the defaults or the options, on either the $.fn.holder or the element 
    // it is instantiated upon. e.g these will work:
    // $.when( $.fn.holder.defaults.execute ).done(hello);
    // $.when( $('#thingIstartedHolderOn').holder.defaults.execute ).done(goodbye);
    
    // this would also work, although options only gets populated after holder is instantiated on something, so call them 
    // after that is done
    // $.when( $.fn.holder.options.execute ).done(hello);
    // $.when( $('#thingIstartedHolderOn').holder.options.execute ).done(goodbye);

    /* functions are expected to end in this order, on init:
      ui
      events
      init
      execute (if executeonload is true, otherwise no more happens until the user triggers it. NOTE execute ends before the ajax query returns)
      success
      error
      render
      review
      display
      add (when the user triggers a UI event bound to this, which then triggers execute again)
      remove (as above)
    */
      

    // They can also be overridden as a group, using $.fn.holder.use. See extend/example.js for an example of a collection 
    // of overrides that could, for example, be used to replace all functions that have to query the backend so that if 
    // a backend other than elasticsearch were necessary, the rewrites there could make it possible
    // (although note, an options.response shaped like an elasticsearch response is expected elsewhere, so if you 
    // were actually trying to do this, make sure that format is replicated)
    
    // additional functions to run after query execution returns results can be added to the displays option below
    // alteranately, just link any files in the displays folder into the html page calling holder, as long as linked 
    // after holder itself, and they will be automatically added to the displays.
    
    // the UI search box can also be used to set options - anything like options.key:val entered in the search box 
    // will override an option
    
    // username and password can also be passed in as options, and will be used to set Auth Basic header
    // or apikey can be passed in and will be used as a query param, or x-apikey can be passed in and used 
    // to set header via beforesend x-apikey, whenever ajax execution occurs

    var obj = $(this); // track what object we are, gets passed to some display functions
    var defaults = {
      class: "holder", // the class name used to identify holder properties for this instance on the page - DO NOT include the .

      url: 'http://localhost:9200/_search', // the URL to send the query to (followed by type and datatype for the query)
      type: "GET", // NOTE that GET is the only supported ajax type at the moment
      datatype: "JSONP",
      
      // define the starting query here - see ES docs. A filtered query is REQUIRED (empties are stripped for old ES compatibility)
      defaultquery: { 
        query: {
          filtered: {
            query: {
              bool: {
                must: [
                ]
              }
            },
            filter: {
              bool: {
                must:[]
              }
            }
          }
        }
      },
      defaultfilters: undefined, // provide a list to go in the default query filtered filter bool must, as convenience to replacing the whole default query
      size: undefined, // size can be set on query start too, to save overwriting whole query (but "from" can't)
      //sort: 'random', // can be the string 'random' which converts the query to a constant_score random sort query with seed for paging, or any ES sort format
      aggregations: undefined, // the aggregations can be defined separate from default query to save having to rewrite the whole thing
      facets: undefined, // for older ES simplicity, facets can be defined too instead of aggregations
      query: undefined, // this could be defined at startup if for some reason should be different from defaultquery
      operator: "AND", // query operator param for the search box query params
      fuzzy: "*", // fuzzify the search box query params if they are simple strings. Can be * or ~ or if false it will not run
      exact: '.exact', // a field name suffix used to map to the .exact mapping so that exact term lookups work as expected. If unnecessary, set to ''
      
      //ui: false, - an example, setting to false overrides the defaults.ui function below, which otherwise will build a search UI if not present
      text: 'search...', // the defaults.placeholder function defines the placeholder content of the .search box after a search executes. Before that, the search box starts with this value by default
      pushstate: true, // try pushing query state to browser URL bar or not
      executeonload: true, // run default search as soon as page loads
      sticky: false, // if sticky, the search bar should stick to the top when scrolling up
      bounce: false, // if true and sticky is false, whenever a search term is entered if the search bar is out of screen, scroll back up to it
      scroll: false, // when results are scrolled to bottom retrieve the next set of results
      // TODO make scroll able to take a div class or id to scroll on, instead of the document
      
      use: [], // list the names of use groups to extend options with. Or as string for just one name. If falsey, but use files have been linked from the html file, all present will be used
      extract: 'hits.hits', // the dot notation to the part of the query execution result object that contains the records to use as results. Leave falsey if not necessary
      // search: false, // example - see below for default function, which also does the default data cleaning, using the default extract value above to find records in a typical elasticsearch response
      // record: function(rec) {}, // example, how to format a record - see below for default function. If false, the default search will run after execution to prep reords, but will not populate the screen
      records: [], // where the cleaned records should be put after search

      // convert: '', // TODO consider conversion of external xml API results, using noddy convert API to retrieve and convert the search URL, then build results from that. If so, this must affect the query execution ajax URL
      // actually in the case of APIs that there is already a use file for, this is unnecessary because that file must define the execute function, and can just use the noddy convert API url if necessary.
      // so may only be useful for on-the-fly demonstrations... could give xml API url, convert true, and fields to build results from...

      display: [
        // a list of functions to run after query ajax execution returns a result set
        // by default execute runs "search" first, which shows results as search results and preps the response result data into 
        // defaults.records. It does this using defaults.record, which is how to format an individual record for display
        // to NOT use the default search display, just set options.record: false
        // but then note, no processing of data into defaults.records will occur either, so this must be handled by the display functions
        // alternatively, overwrite .search with your own data tidying method that just does not write to the page
        // options.paging will still be set here, if it was set by a paging action
        
        // ALTERNATIVELY, if using the displays from the displays folder, just link them from the main page that calls this script
        // in this case, if display is a string it will load only the named display into the display options, or if a list then the listed displays
        // if display is an object as usual, only the ones specified in the object will be used, so specifically name those that you link from displays as well
        // or if displays is not defined or is an empty object (the default) then all linked displays will be used whether specified or not
      ],
      displays: {} // any options specific to a given display - if that display accepts specific options - can be provided here. Each display function shows its default options that it will populate this with

      // export TODO an export function that can open a link to a backend server that will give the current data or selection as json or csv
    };

    defaults.template = '<div class="{{options.class}} sticker"></div>  \
    <div class="{{options.class}} default sticky" style="z-index:1000000;"> \
      <div class="container" style="margin:0px auto 0px auto;padding:0px;"> \
        <div class="row"> \
          <div class="col-md-12"> \
            <div class="panel panel-default holder ui" style="background-color:white;"> \
              <div class="panel-heading" style="background-color:white;padding:0px;"> \
                <div class="input-group" style="margin-left:-1px;margin-top:-1px;margin-bottom:-6px;margin-right:-2px;"> \
                  <div class="input-group-btn"><a class="btn btn-default {{options.class}}" do="previous" alt="previous" title="previous" style="font-weight:bold;height:50px;font-size:1.8em;" href="#">&lt;</a></div> \
                  <input type="text" class="form-control {{options.class}} search suggest" do="add" placeholder="{{options.text}}" style="font-size:1.6em;height:50px;"> \
                  <div class="input-group-btn"> \
                    <a href="#" class="btn btn-default {{options.class}} toggle" toggle=".options" alt="show/hide search options" title="show/hide search options" style="font-weight:bold;height:50px;font-size:1.8em;">+</a> \
                    <a class="btn btn-default {{options.class}}" do="next" alt="next" title="next" style="font-weight:bold;height:50px;font-size:1.8em;" href="#">&gt;</a> \
                  </div> \
                </div> \
                <div class="{{options.class}} searches" style="margin-top:5px;"></div> \
              </div> \
              <div class="panel-body section {{options.class}} options" style="display:none;"> \
                <div class="{{options.class}} suggest"></div> \
                <div class="{{options.class}} display filters"></div> \
                <div class="{{options.class}} display range"></div> \
              </div> \
            </div> \
          </div> \
        </div> \
      </div> \
    </div>';

    defaults.ui = function() {
      // if there is no default UI area on the page for this to run against, append a simple default one
      if ( !$('.' + options.class + '.search').length ) {
        var hb = /\{\{options\.(.+?)\}\}/gi;
        options.template = options.template.replace(hb, function(match, opt) { return dotindex(options,opt); });
        obj.append(options.template);
        $('.'+options.class+'.search').bind('focus',function() { $('.'+options.class+'.options').show(); });
      }
      if ( $('.' + options.class + '.results').length === 0 && typeof options.record === 'function' ) {
        var fr = options.query && options.query.from ? options.query.from : 0;
        $('.' + options.class + '.default').after('<div class="' + options.class + ' results from' + fr + '" style="border:1px solid #ccc;"></div>');
      }
      if ( options.scroll && $('.'+options.class+'.default')) {
        $('.' + options.class + '[do="previous"]').parent().remove();
        $('.' + options.class + '[do="next"]').remove();
      }
    }
    defaults.events = function() {
      if ( typeof options.suggest === 'function' && $('.'+options.class+'.search.suggest').length ) $('.' + options.class + '.search.suggest').bindWithDelay('keyup',function(event) { options.suggest(event,$(this)); }, 500);
      if ( !$('.'+options.class+'.suggest').length && $('.' + options.class + '.search').length ) $('.holder.search').on('focus',function(e) { $('.holder.options').show(); });
      // bind holder prev, next, from, to controllers (and any other functions that someone defines)
      $(document).on('click', '.' + options.class + '[do]:not(input,textarea,select)', function(event) { options[$(this).attr('do')](event,$(this)); } );
      $(document).on('change', 'input.' + options.class + '[do]', function(event) { options[$(this).attr('do')](event,$(this)); } );
      $(document).on('change', 'textarea.' + options.class + '[do]', function(event) { options[$(this).attr('do')](event,$(this)); } );
      $(document).on('change', 'select.' + options.class + '[do]', function(event) { options[$(this).attr('do')](event,$(this)); } );
      // TODO bind holder option buttons
      // TODO bind holder sliders (once interpreting sliders into the query has also been done)
      // bind holder element toggle functions - anything with class toggle will toggle the thing named in the toggle attribute
      $('.' + options.class + '.toggle').on('click',function(e) {
        e.preventDefault(); 
        var t = $(this).attr('toggle');
        if (t.indexOf('.') !== 0 && t.indexOf('#') !== 0) t = '.' + t;
        $(t + '.' + options.class).toggle();
      });
      if ( typeof options.scroller === 'function' ) options.scroller();
      if ( typeof options.sticker === 'function' ) options.sticker();
    };

    // functions to be bound for paging the results
    defaults.paging = false;
    defaults.previous = function(event) {
      if (event) event.preventDefault();
      if ( options.query.from !== 0 ) {
        options.query.from = options.query.from - options.query.size;
        if (options.query.from < 0) options.query.from = 0;
        if ( $('.' + options.class + '.results.from' + options.query.from).length !== 0 ) {
          $('div.' + options.class + '.results').not('.from'+options.query.from).hide();
          $('div.' + options.class + '.results.from' + options.query.from).show();
          options.placeholder();
        } else {
          options.paging = true;
          options.execute();
        }
      }
    };
    defaults.next = function(event) {
      if (event) event.preventDefault();
      if ( options.response && options.query.from + options.query.size < options.response.hits.total) {
        options.query.from = options.query.from + options.query.size;
        if ( $('.' + options.class + '.results.from' + options.query.from).length !== 0 ) {
          $('div.' + options.class + '.results').not('.from'+options.query.from).hide();
          $('div.' + options.class + '.results.from' + options.query.from).show();
          options.placeholder();
        } else {
          options.paging = true;
          options.execute();
        }
      }
    };
    // current example does not actually use from and to boxes at the moment, but could be easily bound to these functions
    // changing the from and to functions is not assumed to be a paging function at the moment, because it redefines the 
    // result space. So these just effectively fire whole new queries
    defaults.from = function() {
      options.query.from = parseInt($('.'+options.class+'.from').val());
      options.execute();
    };
    defaults.to = function() {
      options.query.size = parseInt($('.'+options.class+'.to').val()) - options.query.from;
      if (options.query.size < 0) options.query.size = parseInt($('.'+options.class+'.to').val());
      options.execute();
    };

    // make a search link out of a string, for inclusion on the page, to trigger a search update
    defaults.link = function(opts) {
      if (typeof opts === 'string') opts = {val:opts};
      if (opts.attrs === undefined) opts.attrs = {};
      if (opts.attrs.alt === undefined) opts.attrs.alt = 'search this value';
      if (opts.attrs.title === undefined) opts.attrs.title = 'search this value';
      if (opts.attrs.href === undefined) opts.attrs.href = '#'; // note by default this is going to get overridden by a do action anyway
      if (opts.attrs.do === undefined) opts.attrs.do = 'add';
      if (opts.key !== undefined) opts.attrs.key = opts.key;
      if (opts.val === undefined && opts.attrs.val === undefined && opts.text) opts.val = opts.text;
      if (opts.val !== undefined) opts.attrs.val = opts.val;
      if (opts.class === undefined) opts.class = 'holder link';
      var link = '<a class="' + opts.class + '" ';
      for ( var o in opts.attrs ) {
        link += o + '="' + opts.attrs[o] + '" ';
      }
      link += '>';
      link += opts.text !== undefined ? opts.text : opts.val;
      link += '</a>';
      return link;
    }

    // this function should be bound via holder-function to anything that updates the query
    // it should do whatever is required to add the new search param to the query and then run execute
    // for different UI elements other types of add function could be created, or this one could be overwritten
    // all it must do is somehow add to the options.query, then execute the new search
    // the render function that follows a response being received should render query and results into the UI
    // so if this addition adds something that does not affect the query or results, it may also be necessary to 
    // have a way to represent that on the page (or maybe not...)
    defaults.add = function(event,th) {
      if ( event ) event.preventDefault();
      if (!th) th = $(this);
      if ( options.bounce && !options.sticky && typeof options.bouncer === 'function') options.bouncer($('.' + options.class + '.search'));
      $('.' + options.class + '.options').hide('fast');
      options.query.from = 0;
      var val = th.attr('val') ? th.attr('val') : th.val();
      if (th.val()) th.val("");
      if ( th.attr('key') ) {
        if (options.query.query.filtered.filter === undefined) options.query.query.filtered.filter = {"bool": {"must":[]}};
        if (options.query.query.filtered.filter.bool === undefined) options.query.query.filtered.filter.bool = {"must":[]};
        if (options.query.query.filtered.filter.bool.must === undefined) options.query.query.filtered.filter.bool.must = [];
        var fq = {};
        var key = th.attr('key');
        var ft = th.attr('range') === 'from' ? 'gte' : undefined;
        if (th.attr('range') === 'to') ft = 'lte';
        if (options.ranges && options.ranges[key] !== undefined) {
          if ( options.query.query.filtered.filter.bool.must.length > 0) {
            for ( var fm in options.query.query.filtered.filter.bool.must ) {
              if ( options.query.query.filtered.filter.bool.must[fm].range && options.query.query.filtered.filter.bool.must[fm].range[key] ) {
                if (ft === undefined) ft = 'lte';
                options.query.query.filtered.filter.bool.must[fm].range[key][ft] = val;
              } else {
                fq.range = {};
                fq.range[key] = {};
                if (ft === undefined) ft = 'gte';
                fq.range[key][ft] = val;
                options.query.query.filtered.filter.bool.must.push(fq);
              }
            }
          } else {
            fq.range = {};
            fq.range[key] = {};
            if (ft === undefined) ft = 'gte';
            fq.range[key][ft] = val;
            options.query.query.filtered.filter.bool.must.push(fq);            
          }
        } else {
          fq.term = {};
          //if (options.exact && key.indexOf(options.exact) === -1) key = key + options.exact;
          fq.term[key] = val;
          options.query.query.filtered.filter.bool.must.push(fq);
        }
        // TODO are there other kinds of query filters we could want to add?
        options.execute();
      } else {
        if (val.length > 0) {
          if ( val.indexOf('options.') === 0 ) {
            // options pass-through
            if (val.indexOf(':') === -1) {
              var lk = dotindex(options,val.replace('options.',''));
              console.log(lk);
              var pl = JSON.stringify(lk,function (name, val) { if ( val && typeof val === 'function' ) {return '' + val;} else { return val; } } );
              $('input.'+options.class+'.search').val("").attr('placeholder',pl);
            } else {
              var k = val.substring(8,val.indexOf(':')).replace(' ','');
              var v = val.substring(val.indexOf(':')+1).trim();
              try { v = $.parseJSON(v); } catch(err) {}
              dotindex(options,k,v);
              if ( k === 'use' || k === 'display' ) options.extend();
              options.execute();
            }
          } else if ( val.indexOf(':') !== -1 && val.split(':')[0].indexOf(' ') === -1) {
            var tf = {term:{}};
            var tfk = val.split(':')[0];
            //if (options.exact && tfk.indexOf(options.exact) === -1) tfk = tfk + options.exact; // TODO could limit only to cases where quotes are used, and where not used, do a terms instead of term match
            tf.term[tfk] = val.split(':')[1].replace(/"/g,'');
            if (options.query.query.filtered.filter === undefined) options.query.query.filtered.filter = {"bool": {"must":[]}};
            if (options.query.query.filtered.filter.bool === undefined) options.query.query.filtered.filter.bool = {"must":[]};
            if (options.query.query.filtered.filter.bool.must === undefined) options.query.query.filtered.filter.bool.must = [];
            options.query.query.filtered.filter.bool.must.push(tf);
            options.execute();
          } else if ( val[0] === '"' && val[val.length-1] === '"' ) {
            options.query.query.filtered.query.bool.must.push({"match_phrase": {"_all": val.replace(/"/g,'')}});
            options.execute();
          } else {
            if (options.fuzzy) val = options.fuzzify(val, options.fuzzy);
            options.query.query.filtered.query.bool.must.push({"query_string": {"default_operator":options.operator, "query": val}});
            options.execute();
          }
        }
      }
      $('.'+options.class+'.search').blur();
    }
    // this function should be bound to anything on the UI that removes something from the query
    // it should do whatever necessary to remove a part of the query and then run execute
    defaults.remove = function(event,th) {
      if (event) event.preventDefault();
      $('.' + options.class + '.options').hide('fast');
      if (!th) th = $(this);
      var tgt = th.attr('val').replace('options.','');
      dotindex(options, tgt, undefined, true);
      th.remove(); // TODO should this look for a remove attribute to target a possible parent?
      options.query.from = 0;
      options.execute();
    };

    defaults.suggesting = false; // just tracks the suggesting state
    defaults.suggestions = function(event,th) { // get the suggestions as the user types
      if (event) event.preventDefault();
      if (!th) th = $(this);
      var code = (event.keyCode ? event.keyCode : event.which);
      if ( code == 13 ) {
        if ( options.query.query.filtered.query.bool.must.length !== 0 ) options.query.query.filtered.query.bool.must.splice(-1,1);
        options.add(event,th);
      } else {
        options.suggesting = true;
        options.query.from = 0;
        var v = th.val();
        if ( options.query.query.filtered.query.bool.must.length !== 0 ) options.query.query.filtered.query.bool.must.splice(-1,1);
        if ( v.length !== 0 ) {
          if (options.fuzzy) v = options.fuzzify(v, options.fuzzy);
          options.query.query.filtered.query.bool.must.push({"query_string":{"query": v }});
        }
        options.execute();
      }
    };
    defaults.suggest = function(data) { // what to do with the returned values after a suggestions query
      if (data === undefined) data = options.response;
      $('div.' + options.class + '.suggestions').html('');
      for ( var f in data.aggregations ) {
        var disp = '<div style="float:left;margin-right:10px;max-width:300px;">';
        for ( var r in data.aggregations[f].buckets ) {
            var j = data.aggregations[f].buckets[r];
            disp += options.link({text: j.key + ' (' + j.doc_count + ')', val: f + ':' + j.key });
            disp += '<br>';
        }
        disp += '</div>';
        $('div.' + options.class + '.suggestions').append(disp);
      }      
    }

    // fuzzify the freetext search query terms with elasticsearch fuzzy match signifiers
    defaults.fuzzify = function(querystr, fuzz) {
      var rqs = querystr;
      if ( querystr.indexOf('*') == -1 && querystr.indexOf('~') == -1 && querystr.indexOf(':') == -1 && querystr.indexOf('"') == -1 && querystr.indexOf('AND') == -1 && querystr.indexOf('OR') == -1 && querystr.indexOf(' ') == -1 ) {
        var optparts = querystr.split(' ');
        var pq = "";
        for ( var oi = 0; oi < optparts.length; oi++ ) {
          var oip = optparts[oi];
          if ( oip.length > 0 ) {
            oip = oip + fuzz;
            fuzz == "*" ? oip = "*" + oip : false;
            pq += oip + " ";
          }
        }
        rqs = pq;
      } else {
        rqs = rqs.replace(/[^a-zA-Z ]/g,' ');
      }
      return rqs;
    };
    
    defaults.qry = function() {
      // anything that needs done on first query execution to prep the defaultquery and query object
      if (options.defaultquery.from === undefined) options.defaultquery.from = 0;
      if (options.defaultquery.size === undefined) options.size ? options.defaultquery.size = options.size : options.defaultquery.size = 10;
      if (options.defaultquery.fields === undefined && options.fields) options.defaultquery.fields = options.fields;
      if ( options.sort && options.sort !== 'random' && !options.defaultquery.sort ) options.defaultquery.sort = options.sort;
      if ( options.aggregations && !options.defaultquery.aggregations ) options.defaultquery.aggregations = options.aggregations;
      if ( options.aggs && !options.defaultquery.aggs ) options.defaultquery.aggs = options.aggs;
      if ( options.facets && !options.defaultquery.facets ) options.defaultquery.facets = options.facets;
      if ( options.defaultfilters ) {
        if (options.defaultquery.query.filtered.filter === undefined) options.defaultquery.query.filtered.filter = {"bool": {"must":[]}};
        if (options.defaultquery.query.filtered.filter.bool === undefined) options.defaultquery.query.filtered.filter.bool = {"must":[]};
        options.defaultquery.query.filtered.filter.bool.must = options.defaultfilters;
      }
      if ( !options.query ) options.query = $.extend(true, {}, options.defaultquery);
      // need a check for empty filters and queries for older versions of ES
      if ( options.query.query.filtered ) {
        if (options.query.query.filtered.filter === undefined) options.query.query.filtered.filter = {"bool": {"must":[]}};
        if (options.query.query.filtered.filter.bool === undefined) options.query.query.filtered.filter.bool = {"must":[]};
        try { if ( options.query.query.filtered.filter.bool.must.length === 0 ) delete options.query.query.filtered.filter.bool.must; } catch(err) {}
        try { if ( JSON.stringify(options.query.query.filtered.filter.bool) === '{}' ) delete options.query.query.filtered.filter.bool; } catch(err) {}
        try { if ( JSON.stringify(options.query.query.filtered.filter) === '{}' ) delete options.query.query.filtered.filter; } catch(err) {}
        try { if ( options.query.query.filtered.query.bool.must.length === 0 ) options.query.query.filtered.query.bool.must = [{"match_all":{}}]; } catch(err) {}
        try { if ( options.query.query.filtered.query.bool.must.length > 1 && JSON.stringify(options.query.query.filtered.query.bool.must[0]) === '{"match_all":{}}' ) options.query.query.filtered.query.bool.must.splice(0,1) } catch(err) {}
      }
      // ABOVE do all the things that should update the actual query that we keep track of on options.query and need to know for future queries
      // THEN BELOW clone it and remove things that are not needed for the particular query being prepared, if any
      var tq = $.extend(true, {}, options.query);
      if (options.sort === 'random' && tq.sort === undefined) {
        if (!options.paging) options.seed = Math.floor(Math.random()*1000000000000);
        var fq = {
          function_score : {
            random_score : {seed : options.seed }
          }
        }
        if (tq.query.filtered) {
          fq.function_score.query = tq.query.filtered.query;
          tq.query.filtered.query = fq
        } else {
          fq.function_score.query = tq.query;
          tq.query = fq;
        }
      }
      if ( options.paging ) {
        delete tq.aggs; // if these exist, they do not change during paging, so remove
        delete tq.aggregations;
        delete tq.facets;
      } else if ( options.suggesting ) {
        // TODO could simplify current query if suggesting on facets, drop out ones that are not needed and set result size to zero
        // or maybe suggest should just issue its own ajax...
      }
      if ( options.type !== 'POST' ) {
        options.url = options.url.split('source=')[0];
        if ( options.url.indexOf('?') === -1 ) options.url += '?';
        var last = options.url.substring(options.url.length-1,1);
        if ( last !== '?' && last !== '&' ) options.url += '&';
        options.url += 'source=' + encodeURIComponent(JSON.stringify(tq));
      }
      return tq;
    };

    defaults.success = function(resp) {
      $('.' + options.class + '.loading').hide();
      options.response = resp;
      if ( options.suggesting ) {
        options.suggest();
      } else {
        options.placeholder();
        options.render(); // render the query params onto the page
        if ( typeof options.review === 'function' ) options.review(options.response); // this is run first because it should also do record tidying
        if ( typeof options.display === 'function' ) {
          options.display(); // display could just be one function for most simple behaviour
        } else if ( typeof options.display === 'object' ) {
          for ( var d in options.display ) {
            if ( typeof options.display[d] === 'function' ) options.display[d](obj);
          }
        }
      }
      options.suggesting = false; // reset ongoing actions
      options.paging = false; // paging is assumed to be the same as a new query, so far. But we track that we are doing it, in case anything should behave differently because of it
      // TODO consider should paging really be an increase to data available and a change to results, instead of treated as a new query?
      if ( options.scroll && $(document).height() <= $(window).height() && $('.'+options.class+'.results').length ) options.next();
    }
    defaults.error = function(resp) {
      $('.' + options.class + '.loading').hide();
      $('.' + options.class + '.error').show(); // there is no error object by default, but any added will show here
      console.log('Terribly sorry chappie! There has been an error when executing your query.');
      console.log(resp);
    }
    defaults.executing = false;
    defaults.execute = function(event) {
      if (!options.executing) {
        options.executing = true;
        // hide any prior shown error, and show the loading placeholder (although not defined by default, can be added anywhere to the page)
        $('.' + options.class + '.error').hide();
        $('.' + options.class + '.loading').show();
        $('.' + options.class + '.search').attr('placeholder','searching...');
        setTimeout(function() { // an execute timeout allows multiple programmatic changes to the query before execution actually occurs
          var opts = {
            type: options.type,
            cache: false,
            //contentType: "application/json; charset=utf-8",
            dataType: options.datatype,
            success: options.success,
            error: options.error
          };
          var qr = options.qry(); // prepare the query, which sets the URL if necessary
          opts.url = options.url; // set the URL, which now has the query as a param, if necessary
          if (options.username && options.password) opts.headers = { "Authorization": "Basic " + btoa(options.username + ":" + options.password) };
          if (options.apikey) opts.url += opts.url.indexOf('?') === -1 ? '?apikey=' + options.apikey : '&apikey=' + options.apikey;
          if (options['x-apikey']) opts.beforeSend = function (request) { request.setRequestHeader("x-apikey", options['x-apikey']); };
          // TODO: if options.type is POST, add the qr as data to the ajax opts
          $.ajax(opts);
          options.executing = false;
        },300);
      }
    };

    defaults.placeholder = function() {
      // the text to put in the default search bar as placeholder text
      var found = '';
      if (!options.response || options.response.hits === undefined || options.response.hits.total === undefined) {
        found += 'Sorry, this search did not work. Please try another.';
      } else {
        if (options.scroll) {
          found += options.query.from + options.query.size < options.response.hits.total ? options.query.from + options.query.size : options.response.hits.total;
        //} else if (options.query.from !== 0) {
        //  found += options.query.from + ' to ' + (options.query.from + options.query.size);
        } else {
          found += options.query.from + options.query.size < options.response.hits.total ? options.query.from + options.query.size : options.response.hits.total;
        }
        found += ' of ' + options.response.hits.total;
      }
      $('input.' + options.class + '.search').val("").attr('placeholder',found);
    }
    defaults.render = function() {
      // render info about the query and what it found
      if ( options.pushstate && !options.suggesting ) {
        try {
          if ('pushState' in window.history) window.history.pushState("", "search", '?source=' + JSON.stringify(options.query));
        } catch(err) {
          //console.log('pushstate not working! Although, note, it seems to fail on local file views these days...' + err);
        }
      }
      $('.' + options.class + '.from').val(options.query.from);
      $('.' + options.class + '.to').val(options.query.from + options.query.size);
      $('div.' + options.class + '.searches').html("");
      for ( var q in options.query.query.filtered.query.bool.must ) {
        if (JSON.stringify(options.query.query.filtered.query.bool.must[q]).indexOf('match_all') === -1) {
          var query = JSON.stringify(options.query.query.filtered.query.bool.must[q]).split(':"').pop().split('}')[0].replace(/"/g,'');
          var btn = '<a style="margin:5px;" class="btn btn-default ' + options.class + '" do="remove" val="options.query.query.filtered.query.bool.must.' + q + '"><b>X</b> ' + query + '</a>';
          $('div.' + options.class + '.searches').append(btn);
        }
      }
      if ( options.query.query.filtered.filter && options.query.query.filtered.filter.bool && options.query.query.filtered.filter.bool.must ) {
        for ( var f in options.query.query.filtered.filter.bool.must ) {
          var filter = options.query.query.filtered.filter.bool.must[f];
          var bt = '';
          if (filter.term) {
            bt = '<a style="margin:5px;" class="btn btn-default ' + options.class + '" do="remove" val="options.query.query.filtered.filter.bool.must.' + f + '"><b>X</b> ';
            for (var k in filter.term) bt += ' ' + k.replace(options.exact,'').split('.').pop() + ':' + filter.term[k]; // not actually looping, just get the first key name
            bt += '</a>';
          } else if (filter.range) {
            var key, dkey, gte, lte;
            for ( var kk in filter.range) {
              key = kk.replace(options.exact,'').split('.').pop();
              dkey = options.ranges && options.ranges[key] && options.ranges[key].name ? options.ranges[key].name : key;
              gte = filter.range[kk].gte;
              lte = filter.range[kk].lte;
            }
            // TODO what other kind of range filters can there be?
            if (gte) {
              if (options.ranges && options.ranges[key] && options.ranges[key].date && options.ranges[key].date.display) gte = options.ranges[key].date.display(gte);
              bt = '<a style="margin:5px;" class="btn btn-default ' + options.class + '" do="remove" val="options.query.query.filtered.filter.bool.must.' + f + '.range.' + key + '.gte"><b>X</b> ';
              bt += dkey + ': From ' + gte + '</a>';
            }
            if (lte) {
              if (options.ranges && options.ranges[key] && options.ranges[key].date && options.ranges[key].date.display) lte = options.ranges[key].date.display(lte);
              bt += ' <a style="margin:5px;" class="btn btn-default ' + options.class + '" do="remove" val="options.query.query.filtered.filter.bool.must.' + f + '.range.' + key + '.lte"><b>X</b> ';
              bt += dkey + ': To ' + lte + '</a>';
            }
          }
          // TODO what other kind of filter types can there be?
          $('div.' + options.class + '.searches').append(bt);
        }
      }
    };

    defaults.records = [];
    defaults.record = function(rec,idx) {
      // the default way to format a record for display as a search result
      // NOTE this should not alter the record itself, that should be done by defaults.transform
      var re = '<p style="word-wrap:break-word;padding:5px;margin-bottom:0px;';
      if (idx && parseInt(idx) && parseInt(idx)%2 !== 0) re += 'background-color:#eee;';
      re += '">';
      try {
        for ( var k in rec ) {
          re += '<b>' + k + '</b>: ';
          try {
            if (rec[k] instanceof Array) {
              for ( var i in rec[k] ) {
                if (i !== "0") re += ', ';
                if (typeof rec[k][i] === 'object') {
                  re += JSON.stringify(rec[k][i]);
                } else {
                  re += options.link({text:rec[k][i],val:k+':'+rec[k][i]+''});
                }
              }
            } else if (typeof rec[k] === 'object') {
              re += JSON.stringify(rec[k]);              
            } else {
              re += options.link({text:rec[k],val:k+':'+rec[k]+''});
            }
          } catch(err) {
            re += JSON.stringify(rec[k]);
          }
          re += ' ';
        }
      } catch(err) { re += JSON.stringify(re); }
      re += '</p>';
      return re;
    };
    defaults.transform = function() {
      // TODO this should be the transform function necessary to make an individual record how it needs to be
      // ACTUALLY there could be a default transform that runs unless specifically told not to, and then also 
      // additional transforms, like the use and display approach. Then a use and a display could also define 
      // and append transforms so we only have to run over the data once - they just define the transform in 
      // their scope and then pass the transform name, and the function could be run by index(options,name)()
      // ALSO consider this index approach for use and display themselves - it may be useful to nest uses and 
      // displays in objects, so maybe instead of just checking that the immediate key is a function, should 
      // check if index(options,key) is a function
    };
    defaults.review = function(data) {
      // the default way to display all records as a search result list
      // this display function is always run first if it exists, and should put sanitised records in the options.records list too, for other display functions to use
      if (data === undefined) data = options.response;
      var fromclass='.from' + options.query.from;
      if (options.paging) {
        // TODO this should probably be better as a clone of the results div, not a remake
        $('.' + options.class + '.results').last().after('<div class="' + options.class + ' additional results ' + fromclass.replace('.','') + '"></div>');
        if (!options.scroll) $('div.' + options.class + '.results').not(fromclass).hide();
        // TODO may need to know if paging previous or next, and on previous remove some from records
        // but then note that paging next again would not add, because the query need not run - so would have to store batches of results somewhere
        // and still need to see how well this works with vis views, i.e. adding to the result set instead of just wiping it and starting again
        // (which either way is a problem for paging, if we are not reissuing requests when paging to pages we have already seen)
        // for now, it does it WRONG - a paging event in either direction increases the records in the list, which it should not
      } else {
        options.records = []; // reset the records unless paging, in which case will add to them - is this useful?
        // TODO would it be useful to be passing the records into d3 displays as additional records, or just as display rebuilds each time?
        $('div.' + options.class + '.additional.results').remove();
        $('div.' + options.class + '.results').show().html('');
      }
      // NOTE although it may seem odd to do the data cleaning in the display method, the idea is to minimise iterations 
      // of the response hits, which could be very large. Instead of iterating it to clean the data, then again to build the 
      // page, the first default display iteration builds the default page display and does the tidying. If more display 
      // methods are added then they will incur additional iterations if they require it, or a custom search could
      // be written to do multiple things with each individual record (for d3 etc though it is prob easier to just pass the complete dataset)
      var results = options.extract ? dotindex(data,options.extract) : data;
      var buildfields = false;
      if (!options.fields) {
        options.fields = [];
        buildfields = true; // is this worth doing by default?
      }
      for ( var r in results ) {
        var rec = results[r];
        if (rec.fields) rec = rec.fields;
        if (rec._source) rec = rec._source;
        for ( var f in rec ) { // is this loop worth doing by default?
          if ( rec[f] instanceof Array && rec[f].length === 1) rec[f] = rec[f][0];
          if ( rec[f] !== 0 && rec[f] !== false && !rec[f] ) rec[f] = "Not found";
          if (buildfields && typeof rec[f] === 'string' && options.fields.indexOf(f) === -1) options.fields.push(f); // don't do anything clever with objects by default
        }
        options.records.push(rec);
        if (typeof options.record === 'function') {
          $('.' + options.class + '.results'+fromclass).append(options.record(rec,r));
        }
      }
    }
    
    defaults.scroller = function() {
      $(window).scroll(function() {
        if (options.scroll === true) {
          if ( !options.paging && $(window).scrollTop() >= $(document).height() - $(window).height() * 1.2) options.next();
        } else if (typeof options.scroll === 'string') {
          // TODO if it is a div ID or class set, then do the scroll on that div instead - also check elsewhere that scrolling may cause reloads etc
        }
      });
    }
    
    defaults.bouncer = function(elem) {
      if (elem === undefined) elem = $('.'+options.class+'.search');
      var doctop = $(window).scrollTop();
      var docbottom = doctop + $(window).height();
      var top = elem.offset().top;
      if ( top < 150 ) top = 0;
      var bottom = top + elem.height();
      if ( bottom > docbottom || top <  doctop ) $('html, body').animate({ scrollTop: top - 10 }, 200);
    }

    defaults.stickermargintop;
    defaults.stickerheight;
    defaults.stickerz;
    defaults.sticker = function() {
      var sticker = $('.'+options.class+'.sticker');
      var sticky = $('.'+options.class+'.sticky');

      var move = function() {
        if (options.sticky === true) {
          var st = $(window).scrollTop();
          var ot = sticker.offset().top;
          if(st > ot) {
            if (options.stickerheight === undefined) options.stickerheight = sticker.height();
            if (options.stickermargintop === undefined) options.stickermargintop = sticky.css('margin-top');
            if (options.stickerz === undefined) options.stickerz = sticky.css('z-index');
            $('.'+options.class+'.options').hide();
            sticky.css({
              position: "fixed",
              "margin-top": "0px",
              "z-index": "100000000000000000000000000000",
              top: "0px",
              left:"0px",
              right:"0px"
            });
            sticker.css('height',sticky.height() + 'px');
          } else {
            if(st <= ot) {
              sticker.css('height',options.stickerheight + 'px');
              sticky.css({
                position: "relative",
                "margin-top": options.stickermargintop,
                "z-index": options.stickerz,
                top: "",
                left: "",
                right: ""
              });
              options.stickermargintop = undefined;
              options.stickerheight = undefined;
              options.stickerz = undefined;
            }
          }
        }
      };
      $(window).scroll(move);
    }
    
    var originals;
    defaults.extend = function() {
      if (originals === undefined) {
        originals = options;
        options = $.extend(defaults, options);
      } else {
        options = $.extend(defaults, originals);
      }
      if (typeof options.use === 'string') {
        options.use = options.use.indexOf(',') !== -1 ? options.use.split(',') : [options.use];
      }
      if (options.use && options.use.length === 0) {
        for ( var ou in $.fn.holder.use ) options.use.push(ou);
      }
      if ( options.use instanceof Array ) {
        // what about uses that also have same-named display? add/remove them together? or leave to specific actions?
        for ( var u in options.use ) {
          if ( $.fn.holder.use[options.use[u]] !== undefined) options = $.extend(options, $.fn.holder.use[options.use[u]]);
        }
      }
      if (typeof options.display === 'string') {
        options.display = options.display.indexOf(',') !== -1 ? options.display.split(',') : [options.display];
      }
      if (options.display && options.display.length === 0) {
        for ( var od in $.fn.holder.display ) options.display.push(od);
      }
      if (options.display instanceof Array) {
        $('.'+options.class+'.display').remove();
        var dl = options.display;
        options.display = {};
        for ( var o in dl ) {
          if ($.fn.holder.display[dl[o]] !== undefined && typeof $.fn.holder.display[dl[o]] === 'function') {
            options.display[dl[o]] = $.fn.holder.display[dl[o]];
            if ( $.fn.holder.display[dl[o]].init && $.fn.holder.display[dl[o]].extend ) {
              for ( var e in $.fn.holder.display[dl[o]].extend ) $.when( options[e] ).then(function() { $.fn.holder.display[dl[o]].extend[e](options); } );
            }
          }
        }
      } else if (options.display === false) {
        $('.'+options.class+'.display').remove(); 
        // TODO if the above binds extensions to functions for a display, how to remove them on display change?
      }
    }
    defaults.extend();
    
    defaults.init = function() {
      if (typeof options.ui === 'function') options.ui();
      if (typeof options.events === 'function') options.events();
      if ( $.params('source') ) {
        if (typeof $.params('source') === 'string') {
          options.query = JSON.parse($.params('source'));
        } else {
          options.query = $.params('source');          
        }
      }
      if ( $.params('q') ) {
        options.qry();
        options.query.query.filtered.query.bool.must = [ {"query_string": { "query": $.params('q') } } ];
      }
      for ( var p in $.params() ) {
        if (p !== 'source' && p !== 'q') options[p] = $.params(p);
      }
      if (!options.executeonload) options.qry();
      if ( options.executeonload || JSON.stringify($.params()) !== "{}" ) options.execute();
    }
    
    $.fn.holder.defaults = defaults;
    $.fn.holder.options = options; // make the defaults and options externally available, for extension
    return this.each(function() {
      // anything else that must be done on all initialisations can go here. Anything that could be customised should go above in .init
      options.init();
    });

  };

  // define things here to make them available externally
  $.fn.holder.defaults = {};
  $.fn.holder.options = {};
  $.fn.holder.use = {};
  $.fn.holder.display = {};
    
})(jQuery);








// BELOW ARE SOME THINGS THAT HOLDER RELIES ON BEING DEFINED ON JQUERY AND JS, PLUS A FUNCTION TO INDEX OBJECTS WITH DOT NOTATION

// TODO how should this handle calls to lists? like, append to list at wrong integer place, or provide list as value...
function dotindex(ob, is, value, del) {
  if (typeof is == 'string') {
    return dotindex(ob, is.split('.'), value, del);
  } else if (is.length == 1 && ( value !== undefined || del !== undefined ) ) {
    if ( del === true ) {
      if (ob instanceof Array) {
        ob.splice(is[0],1);
      } else {
        delete ob[is[0]];
      }
      return true;
    } else {
      ob[is[0]] = value;
      return true;
    }
  } else if (is.length === 0) {
    return ob;
  } else {
    if ( ob[is[0]] === undefined ) {
      if ( value !== undefined ) {
        ob[is[0]] = isNaN(parseInt(is[0])) ? {} : [];
        return dotindex(ob[is[0]], is.slice(1), value, del);
      } else {
        return undefined;
      }
    } else {
      return dotindex(ob[is[0]], is.slice(1), value, del);
    }
  }
}

// function to bind change on delay, good for text search autosuggest
(function($) {
  $.fn.bindWithDelay = function( type, data, fn, timeout, throttle ) {
    var wait = null;
    var that = this;
    if ( $.isFunction( data ) ) {
      throttle = timeout;
      timeout = fn;
      fn = data;
      data = undefined;
    }
    function cb() {
      var e = $.extend(true, { }, arguments[0]);
      var throttler = function() {
        wait = null;
        fn.apply(that, [e]);
      };
      if (!throttle) { clearTimeout(wait); }
      if (!throttle || !wait) { wait = setTimeout(throttler, timeout); }
    }
    return this.bind(type, data, cb);
  };
})(jQuery);

// add extension to jQuery with a function to get URL parameters
jQuery.extend({
  params: function(name) {
    var params = new Object;
    var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
    for ( var i = 0; i < hashes.length; i++ ) {
      hash = hashes[i].split('=');
      if ( hash.length > 1 ) {
        if ( hash[1].replace(/%22/gi,"")[0] == "[" || hash[1].replace(/%22/gi,"")[0] == "{" ) {
          hash[1] = hash[1].replace(/^%22/,"").replace(/%22$/,"");
          var newval = JSON.parse(unescape(hash[1].replace(/%22/gi,'"')));
        } else {
          var newval = unescape(hash[1].replace(/%22/gi,'"'));
        }
        params[hash[0]] = newval;
      }
    }
    return name !== undefined ? params[name] : params;
  }
});

// Deal with indexOf issue in <IE9
// provided by commentary in repo issue - https://github.com/okfn/facetview/issues/18
if (!Array.prototype.indexOf) {
  Array.prototype.indexOf = function(searchElement /*, fromIndex */ ) {
    "use strict";
    if (this == null) {
      throw new TypeError();
    }
    var t = Object(this);
    var len = t.length >>> 0;
    if (len === 0) {
      return -1;
    }
    var n = 0;
    if (arguments.length > 1) {
      n = Number(arguments[1]);
      if (n != n) { // shortcut for verifying if it's NaN
        n = 0;
      } else if (n !== 0 && n != Infinity && n != -Infinity) {
        n = (n > 0 || -1) * Math.floor(Math.abs(n));
      }
    }
    if (n >= len) {
      return -1;
    }
    var k = n >= 0 ? n : Math.max(len - Math.abs(n), 0);
    for (; k < len; k++) {
      if (k in t && t[k] === searchElement) {
        return k;
      }
    }
    return -1;
  }
}
