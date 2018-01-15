
$('<link/>', { rel:'stylesheet', type: 'text/css', href: '//static.cottagelabs.com/bootstrap-slider/slider.css' }).appendTo('head');

$.fn.holder.display.range = function(obj) {
  var options = obj.holder.options;
  if (options.paging) return; // do nothing when just paging results

  // TODO is it worth trying to auto-guess some range fields? Like on things that look like dates?
  // TODO if range facet results are present, should ranges be extracted from range facet results?

  /* options.ranges can take the form of:
  options.ranges = {
    createdAt: {
      name: 'Created',
      date: { // date should either be an object or not defined
        value: function(date) {
          // should be a function that customises the provided value into a unix timestamp - NOTE js timestamps are 13 digits, unix are 10, so customise
          if (typeof date === 'string') date = parseInt(date);
          var dv = date.toString().length > 10 ? Math.floor(date/1000) : date;
          dv = dv - dv%86400; // also converts to start of current day
          return dv;
        },
        display: function(date) {
          // should be a function that customises the customised value for display
          if (typeof date === 'string') date = parseInt(date);
          if (date.toString().length <= 10) date = date * 1000;
          var d = new Date(date);
          var dd = d.getDate() + '/' + (d.getMonth()+1) + '/' + d.getFullYear();
          return dd;
        },
        submit: function(date,max) {
          // should be a function that converts the values back into the necessary format for submitting on the query
          if (typeof date === 'string') date = parseInt(date);
          var ds = date.toString().length <= 10 ? date * 1000 : date;
          if (max) ds += 86400; // to make sure we get things created during the max day
          return ds;
        }
      },
      step: 86400, // the value that steps the date by required chunk sizes - that is, for a day step on a js timestamp, 86400000ms moves forward one day - on unix timestamp, just 86400 will do for seconds
      min: 1356998400 // min and max could be functions that query a remote - in some cases there could be endpoints that serve the min and max
    }
  }
  */

  if (options.ranges) {

    if ( !$('.'+options.class+'.range').length ) {
      if ( $('.'+options.class+'.options').length ) {
        $('.'+options.class+'.options').append('<div class="' + options.class + ' range display"></div>');
      } else {
       obj.append('<div class="' + options.class + ' range display"></div>');
      }
    }

    $('.'+options.class+'.range').html("");

    for ( var r in options.ranges ) {
      var step = options.ranges[r].step ? options.ranges[r].step : 1;
      if (options.ranges[r].min === undefined) options.ranges[r].min = 946684800;
      if (options.ranges[r].max === undefined) options.ranges[r].max = Math.floor((new Date()).valueOf()/1000)+86400;
      var vals = [options.ranges[r].min, options.ranges[r].max];
      try {
        for ( var fm in options.query.query.filtered.filter.bool.must ) {
          if ( options.query.query.filtered.filter.bool.must[fm].range && options.query.query.filtered.filter.bool.must[fm].range[r] ) {
            if (options.query.query.filtered.filter.bool.must[fm].range[r].gte) vals[0] = parseInt(options.query.query.filtered.filter.bool.must[fm].range[r].gte);
            if (options.query.query.filtered.filter.bool.must[fm].range[r].lte) vals[1] = parseInt(options.query.query.filtered.filter.bool.must[fm].range[r].lte);
            if (options.ranges[r].date && options.ranges[r].date.value) {
              vals[0] = options.ranges[r].date.value(vals[0]);
              vals[1] = options.ranges[r].date.value(vals[1]);
            }
          }
        }
      } catch(err) {}
      var n = options.ranges[r].name ? options.ranges[r].name : r;
      var low = options.ranges[r].date && options.ranges[r].date.display ? options.ranges[r].date.display(vals[0]) : vals[0];
      var high = options.ranges[r].date && options.ranges[r].date.display ? options.ranges[r].date.display(vals[1]) : vals[1];
      var ranger = '<p style="text-align:center;font-size:0.8em;margin-top:0px;margin-bottom:-18px;">';
      ranger += n + ': <span class="' + options.class + ' rangelow ' + r + '">' + low + '</span> to <span class="' + options.class + ' rangehigh ' + r + '">' + high + '</span></p>';
      ranger += '<input key="' + r + '" style="width:100%;" class="' + options.class + ' ranger" type="text"/>';
      $('.'+options.class+'.range').append(ranger);
      $.getScript("//static.cottagelabs.com/bootstrap-slider/slider.js").done(function() {
        $('.'+options.class+'.ranger').last().slider({ min: options.ranges[r].min, max: options.ranges[r].max, value: vals, step: step, tooltip:'hide' })
        .on('slide',function(e) {
          var low = $(this).attr('key') && options.ranges[$(this).attr('key')]  && options.ranges[$(this).attr('key')].date && options.ranges[$(this).attr('key')].date.display ? options.ranges[$(this).attr('key')].date.display(e.value[0]) : e.value[0];
          $('.'+options.class+'.rangelow.'+r).text(low);
          var high = $(this).attr('key') && options.ranges[$(this).attr('key')]  && options.ranges[$(this).attr('key')].date && options.ranges[$(this).attr('key')].date.display ? options.ranges[$(this).attr('key')].date.display(e.value[1]) : e.value[1];
          $('.'+options.class+'.rangehigh.'+r).text(high);
        })
        .on('slideStop',function(e) {
          var low = $(this).attr('key') && options.ranges[$(this).attr('key')]  && options.ranges[$(this).attr('key')].date && options.ranges[$(this).attr('key')].date.submit ? options.ranges[$(this).attr('key')].date.submit(e.value[0]) : e.value[0];
          $(this).attr('val',low);
          $(this).attr('range','from');
          options.add(undefined,$(this));
          var high = $(this).attr('key') && options.ranges[$(this).attr('key')]  && options.ranges[$(this).attr('key')].date && options.ranges[$(this).attr('key')].date.submit ? options.ranges[$(this).attr('key')].date.submit(e.value[1],true) : e.value[1];
          $(this).attr('val',high);
          $(this).attr('range','to');
          options.add(undefined,$(this));
        });
      });
    }

    // if a value is clicked on screen, and it meets a range field name, should it be just searched on or used as range value?
    // how to decide which to do? exact search or range search?

    // for each field to range on, need to know the min and max values
    // these could be provided by a particular filter on the query, or two sorted queries to the backend returning just that field, asc then desc
    // so at start time, something needs to know how to get these values
    // and perhaps they have to change too, as other selections are made? In which case a facet/agg would be best approach
    // probably best to have the data review process know how to extract ranges?
    // this leans towards needing these displays to be able to add functionality onto the other methods too, then...

    // then draw a range slider with min and max value (possibly also select / datepicker) boxes at each end
    // on slide, update the box values
    // on box value change, bind to the usual add method

    // so add needs to know how to build a range filter into the query too
  }

}


