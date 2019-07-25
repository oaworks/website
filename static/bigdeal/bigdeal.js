var _bigdeal_opts = undefined;

var _bigdeal_template = '\
  <style>button.rangebutton:hover { color:#151717 !important; background-color:transparent !important; } .slider-handle { background-color: #D82D34; } .btn-default.holder:not(.btn-block) { width: auto; display: inline-block; } .btn-primary.holder:not(.btn-block) { width: auto; display: inline-block; }</style>\
  <div id="holder">\
  <div class="holder sticker"></div>\
  <div class="holder default sticky" style="z-index:1000000;">\
    <div class="panel panel-default holder ui" style="background-color:white;">\
      <div class="panel-heading" style="background-color:white;padding:0px;">\
        <div class="input-group" style="margin-left:-1px;margin-top:-1px;margin-bottom:-6px;margin-right:-2px;">\
          <!--<div class="input-group-btn"><a class="btn btn-default holder" do="previous" alt="previous" title="previous" style="font-weight:bold;height:50px;font-size:1.8em;" href="#">&lt;</a></div>-->\
          <input type="text" class="form-control holder search suggest" do="add" placeholder="Search" style="font-size:1.6em;height:50px;border-bottom:1px solid #D82D34;">\
          <div class="input-group-btn">\
            <a class="btn btn-primary holder" do="execute" alt="search" title="search" style="font-weight:bold;height:50px;background-color:#D82D34;padding-top:5px;padding-left:10px;padding-right:10px;" href="#"><img src="XXXstaticXXX/search_hi_white_cropped.png" style="height:32px;padding-top:8px;"></img></a>\
            <!--<a class="btn btn-default holder" do="next" alt="next" title="next" style="font-weight:bold;height:50px;font-size:1.8em;" href="#">&gt;</a>-->\
          </div>\
        </div>\
        <div class="holder searches" style="margin-top:5px;"></div>\
      </div>\
      <div class="panel-body section holder options">\
        <div class="holder filters"></div>\
        <div class="holder range"></div>\
        <!--<div class="col-md-4"><div style="border:1px solid #ccc;border-radius:4px;padding:5px;"><input type="checkbox" id="completes" class="holder" do="completes" val="url:*"> Complete agreements only</div></div>-->\
        <div class="col-md-8 holder sort" style="margin-left:5px;margin-right:-5px;display:none;"></div>\
        <div class="col-md-12">\
          <a class="btn btn-default btn-block exporter" style="height:34px;padding-top:6px;" val="csv" href="#" target="_blank">Download</a>\
        </div>\
      </div>\
    </div>\
  </div>\
  <table class="table table-bordered table-striped tabular pages">\
    <thead>\
      <th style="width:20%;background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="institution.exact" class="sorters">Institution <img style="height:10px;" src="XXXstaticXXX/up_grey_cropped.png"></a></th>\
      <th style="background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="publisher.exact" class="sorters">Publisher <img style="height:10px;" src="XXXstaticXXX/up_grey_cropped.png"></a></th>\
      <th style="width:14%;background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="collection.exact" class="sorters">Collection <img style="height:10px;" src="XXXstaticXXX/up_grey_cropped.png"></a></th>\
      <th style="background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="fte" class="sorters">FTE <img style="height:10px;" src="XXXstaticXXX/up_grey_cropped.png"></a></th>\
      <th style="width:14%;background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="carnegiebasicclassification.exact" class="sorters">Carnegie <img style="height:10px;" src="XXXstaticXXX/up_grey_cropped.png"></a></th>\
      <th style="background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="years.exact" class="sorters">Year <img style="height:10px;" src="XXXstaticXXX/up_grey_cropped.png"></a></th>\
      <th style="width:14%;background-color:#eee;font-weight:bold;"><a alt="click to sort" title="click to sort" href="value" class="sorters">USD Value <img style="height:10px;" src="XXXstaticXXX/down_red_cropped.png"></a></th>\
    </thead>\
    <tbody class="holder results"></tbody>\
  </table>\
  <div class="row lowercontrols" style="display:none;">\
    <div class="col-md-4">\
      <a class="btn btn-default btn-block holder lowercontrol" do="previous" alt="previous" title="previous" href="#">&lt; previous results</a>\
    </div>\
    <div class="col-md-4">\
      <a class="btn btn-default btn-block backtotop" alt="back to top" title="back to top" href="#">back to top</a>\
    </div>\
    <div class="col-md-4">\
      <a class="btn btn-default btn-block holder lowercontrol" do="next" alt="next" title="next" href="#">next results &gt;</a>\
    </div>\
  </div>\
</div>';
        
var bigdeal_build = function() {
  jQuery(document).ready(function() {
    var opts = _bigdeal_opts;
    var api = opts.api ? opts.api : 'https://dev.api.cottagelabs.com/service/bigdeal';
  
    $(opts.target).append(opts.template);
    $('body').on('click','.backtotop', function(e) {
      if (e) e.preventDefault();
      $('html,body').animate({ scrollTop: 0 }, 'fast');
    });
    $('body').on('click','.sorters', function(e) {
      if (e) e.preventDefault();
      var w = $(this).attr('href') !== '#' ? $(this).attr('href') : $(this).html().toLowerCase();
      var cs = $('.holder.sortfield').val();
      var icon = $(this).children('img').attr('src');
      var src = opts.static.replace('https:','').replace('http:','');
      src += icon.indexOf('red') === -1 ? (icon.indexOf('up') !== -1 ? 'up' : 'down') : (icon.indexOf('up') === -1 ? 'up' : 'down');
      $(this).children('img').attr('src',src + '_red_cropped.png');
      $(this).parent().siblings().children().children('img').each(function() {
        if ($(this).attr('src').indexOf('red') !== -1) $(this).attr('src',$(this).attr('src').replace('red_','grey_'));
      });
      if (cs === w) {
        $('.holder.sortdirection').val($('.holder.sortdirection').val() !== 'asc' ? 'asc' : 'desc').trigger('change');
      } else {
        $('.holder.sortdirection').val('asc');
        $('.holder.sortfield').val(w).trigger('change');
      }
    });
    
    var record = function(rec,idx) {
      var options = $.fn.holder.options;
      var fromclass='.from' + options.query.from;
      var rr = '';
      var iid = rec.institution.replace(/ /g,'_');
      if (rec.years) {
        rr += '<tr class="holder result from' + fromclass + '"><td style="max-width:400px;overflow-wrap:break-word;"><h5 style="margin-bottom:3px;">' + (rec.url ? '<a target="_blank" alt="View the agreement" title="View the agreement" href="' + rec.url + '">' + rec.institution + '</a>' : rec.institution) + '</h5>';
        rr += '<p style="font-size:1em;">' + (rec.notes && rec.notes.toLowerCase().trim() !== 'not found' ? rec.notes : '') + '</p>';
        rr += '</td><td>' + rec.publisher + '</td><td>' + rec.collection + '</td>';
        rr += '<td>' + rec.fte + '</td><td>' + rec.carnegiebasicclassification + '</td><td>' + rec.years + '</td><td>$' + rec.usdvalue + '</td></tr>';
      }
      return rr;
    }    
  
    var exporter = function(e) {
      var q = JSON.parse(JSON.stringify($('#holder').holder.options.query))
      q.size = $('#holder').holder.options.response.hits.total;
      $(this).attr('href', api + '.csv?source=' + encodeURIComponent(JSON.stringify(q)));
    }
    $('.exporter').bind('click',exporter);
  
    var _citv = undefined;
    var completes = function(event,th) {
      if (th.is(':checked')) {
        $('#holder').holder.options.defaultfilters = [{"query_string": {"query": "url:*"}}];
        setInterval(function() {
          if ($('a.holder:contains(\'url:*\')').length) {
            $('a.holder:contains(\'url:*\')').hide();
            clearInterval(_citv);
            _citv = undefined;
          }
        }, 100);
      } else {
        $('#holder').holder.options.defaultfilters = [];
        $('#holder').holder.options.remove(undefined, $('a.holder:contains(\'url:*\')'));
      }
      $('#holder').holder.options.execute();
    }

    var review = function(data) {
      $('.lowercontrols').show();
      var options = $('#holder').holder.options;
      if (data === undefined) data = options.response;
      var fromclass='.from' + options.query.from;
      if (options.paging) {
        if (!options.scroll) $('.' + options.class + '.result').not(fromclass).hide();
      } else {
        options.records = [];
        $('.' + options.class + '.result').remove();
      }
      var results = options.extract ? dotindex(data,options.extract) : data;
      for ( var r in results ) {
        var rec = results[r];
        if (rec.fields) rec = rec.fields;
        if (rec._source) rec = rec._source;
        for ( var f in rec ) { // is this loop worth doing by default?
          if ( rec[f] instanceof Array && rec[f].length === 1) rec[f] = rec[f][0];
          if ( rec[f] !== 0 && rec[f] !== false && !rec[f] ) rec[f] = "Not found";
        }
        options.records.push(rec);
        if (typeof options.record === 'function') {
          $('.' + options.class + '.results').append(options.record(rec,r));
        }
      }
    }

    $.fn.holder.display.sort.fields = ['institution.exact','publisher.exact','collection.exact','fte','carnegiebasicclassification.exact','years.exact','value'];
    $.fn.holder.display.sort.default = {'value': 'desc'};

    $('#holder').holder({
      completes: completes,
      review: review,
      url: api,
      datatype: 'JSON',
      pushstate: false,
      record: record,
      collapse: false,
      //sort: 'institution.exact',
      //sticky:true,
      display: ['filters','range','sort'],
      size: 100,
      facets: {
        institution: { terms: { field: "institution.exact", size: 1000, order: "term" } },
        publisher: { terms: { field: "publisher.exact", size: 1000, order: "term", exclude: [''] } },
        'Carnegie': { terms: { field: "carnegiebasicclassification.exact", size: 1000, order: "term" } },
        collection: { terms: { field: "collection.exact", size: 1000, order: "term" } }
      },
      ranges: {
        usdvalue: {
          name: 'USD Value',
          step: 100,
          min: 0,
          max: 10000000
        },
        years: {
          name: 'Years',
          step: 1,
          min: 2002,
          max: 2022
        },
        fte: {
          name: 'FTE',
          step: 10,
          min: 100,
          max: 100000
        }
      }
    });
  });
};

var _bigdeal_got = 0;
var bigdeal_get = function() {
  var headTag = document.getElementsByTagName("head")[0];
  var need = ['/holder/jquery.holder.js','/holder/display/filters.js','/holder/display/sort.js','/holder/display/range.js'];
  var jqTag = document.createElement('script');
  jqTag.type = 'text/javascript';
  jqTag.src = _bigdeal_opts.static + need[_bigdeal_got];
  if (_bigdeal_got === need.length-1) {
    jqTag.onload = bigdeal_build;
  } else {
    _bigdeal_got += 1;
    jqTag.onload = bigdeal_get;
  }
  headTag.appendChild(jqTag);
}

var bigdeal_setup = function(opts) {
  if (opts === undefined) opts = {}
  if (opts.api === undefined) opts.api = 'https://api.cottagelabs.com/service/bigdeal';
  //if (opts.site === undefined) opts.site = 'https://bigdeal.test.cottagelabs.com';
  if (opts.static === undefined) opts.static = 'https://openaccessbutton.org/static/bigdeal';
  if (opts.target === undefined) opts.target = '#bigdeal';
  if (opts.template === undefined) opts.template = _bigdeal_template;
  opts.template = opts.template.replace(/XXXstaticXXX/g,opts.static.replace('https:','').replace('http:',''));
  _bigdeal_opts = opts;

  if ($ === undefined) {
    var headTag = document.getElementsByTagName("head")[0];
    var jqTag = document.createElement('script');
    jqTag.type = 'text/javascript';
    jqTag.src = opts.static + '/jquery-1.10.2.min.js';
    jqTag.onload = bigdeal_get;
    headTag.appendChild(jqTag);
  } else {
     bigdeal_get();
  }
}
