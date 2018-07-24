

// this graph display assumes the default search display has already tidily created options.results

// TODO as the first example of it, have this display define a .transform() function that will be called 
// by the main transform function, to make the records meet the requirements for this display

// need to sort the records by the chosen date too - but this should not be done to the records list in general

// what if this display needs to run against returned filters or other values instead of the records? 
// could probably just do the necessary data cleaning right here in that case - unlikely to be much use 
// to other displays. However, could also add to this example an ability to line chart any filters 
// instead of or as well as the main data.

// to build a generic line chart for any values, would need to parse record for any key that look like 
// a date - find a way to test all fields for date, or see if they have "date" in their name, or createdAt - updatedAt
// what if more than one field appears to be a date? Which to use? Provide as options?

// then need to be able to line out values for all records
// so - a line for the records would most simply just be a count of all the records with same createdAt date, for example
// or could be records with same createdAt date that share key of some value? 

// also need to be able to group them - so by default group by day on the date, but could also do month, year, hour, minute?

// may be better having an overall flow like:
/*
- options.execute
calls options.review
which calls for each options.reviewer['fn1','fn2']
and looks for index(options,fn1) and runs it if a function
- so where would displays put those functions? should displays be objects, not functions, with an init?
each reviewer does whatever may be necessary at a WHOLE results level
then options.review goes on to call options.transform
options.transform does the default transform (unless some way to disable the default transform)
then options.transform looks in options.transformer for list of transformers
(same issues as above - decide where to find these named transformer functions)
so each display can define a transformer function that needs to run at a RECORD level
options.review then also runs options.record for each record, unless it is set to false
*/

$.fn.holder.display.line = function(obj) {
  var options = obj.holder.options;
  
  var parseTime = d3.timeParse("%d-%b-%y");

	var fill = d3.scaleOrdinal(d3.schemeCategory10);

	var filter = function(d) { 
		$('.'+options.class+'.search').val('createdAt:'+d.date.valueOf()).trigger('change');
	}

  var line = function(data) {
    var svg = d3.select("svg.holder.line"),
      margin = {top: 10, right: 5, bottom: 10, left: 25},
      width = +svg.attr("width") - margin.left - margin.right,
      height = +svg.attr("height") - margin.top - margin.bottom,
      g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    var x = d3.scaleTime()
      .rangeRound([0, width]);

    var y = d3.scaleLinear()
      .rangeRound([height, 0]);

    var line = d3.line()
      .x(function(d) { return x(d.date); })
      .y(function(d) { return y(d.val); });

		/* curved line option possibility
		var line = d3.line()
			.curve(d3.curveCatmullRomOpen)
			.x(function(d) { return x(d.date); })
			.y(function(d) { return y(d.val); });*/
		
		/* example data:    
		data = [
      { date: parseTime('24-Apr-07'), close: +93.24 },
      { date: parseTime('24-Jul-07'), close: +90.24 }
    ]*/

    x.domain(d3.extent(data, function(d) { return d.date; })).range([0, width - margin.left - margin.right]);
    y.domain(d3.extent(data, function(d) { return d.val; })).nice().range([height - margin.top - margin.bottom, 0]);

    g.append("g")
      .attr("class", "axis")
      .attr("transform", "translate(0," + y.range()[0] + ")")
      .call(d3.axisBottom(x)
				.ticks( 10 )
				//.tickSize(-(height - margin.top - margin.bottom),0,0)
				.tickSizeOuter(0)
			);

    g.append("g")
      .attr("class", "axis")
      .call(d3.axisLeft(y)
				.ticks( 10 )
				//.tickSize(-(width - margin.right - margin.left),0,0)
				.tickSizeOuter(0)
			);

    g.append("path")
      .datum(data)
      .attr("class", "line values")
      .attr("d", line)
			//.attr("d", d3.line()
      //             .curve(d3.curveLinear)
      //             .x(function(d) { return x(d.date); })
      //             .y(function(d) { return y(d.val); })
			//)
			.style('fill', 'none' )
      .attr("stroke", function(d) { return fill(d.key); })
			.style('stroke-width', '1.3px' );
		
    svg.selectAll("dot")
      .data(data)
      .enter().append("circle")
      .attr("r", 2.5)
      .attr("cx", function(d) { return x(d.date) + margin.left; })
      .attr("cy", function(d) { return y(d.val) + margin.top; })
			.attr("class","holder dot")
      .attr("stroke", function(d) { return fill(d.key); })
      .attr("fill", function(d) { return fill(d.key); })
			.attr("do", "add")
			.attr("key","createdAt")
			.attr("val",function(d) { return d.date.valueOf(); })
			.style('cursor', 'pointer' )
      .append("title")
      .text(function(d) { return d.val + " on " + (d.text ? d.text : d.date); });
	}

  if ( !$('div.'+options.class+'.line').length ) {
		obj.append('<div class="' + options.class + ' display line" style="outline:1px solid #ccc;margin-top:20px;height:500px;padding-left:5px;padding-right:5px;"><svg class="' + options.class + ' line"></svg></div>');
	}
	if ( !$('svg.'+options.class+'.line').attr('height') ) {
		var dh = $('div.'+options.class+'.line').height() - ($('svg.'+options.class+'.line').offset().top - $('svg.'+options.class+'.line').parent().offset().top);
		$('svg.'+options.class+'.line').attr('height',dh);
	}
	if ( !$('svg.'+options.class+'.line').attr('width') ) {
		var dw = $('div.'+options.class+'.line').width();
		$('svg.'+options.class+'.line').attr('width',dw);
	}

  var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var lineit = function(e) {
		$('svg.' + options.class + '.line').html("");
    var dates = {};
		for ( var r in options.records ) {
      if (options.records[r].createdAt) {
        var date = new Date(options.records[r].createdAt);
        var month = date.getMonth();
        var day = date.getDate();
        var year = date.getFullYear();
        if (day.toString().length === 1) day = "0" + day;
        var ts = day + '-' + months[month] + '-' + year.toString().substring(2,4);
        if (dates[ts] === undefined) dates[ts] = 0;
        dates[ts] += 1;
      }
		}
		var data = [];
    for ( var d in dates ) data.push({text:d,date:parseTime(d),val:dates[d]});
    data.sort(function(a,b) {
      var keyA = new Date(a.date);
      var keyB = new Date(b.date);
      if(keyA < keyB) return -1;
      if(keyA > keyB) return 1;
      return 0;
    });
    line(data);
	}
  lineit();

	for ( var e in obj.holder.display.line.extend ) $.when( options[e] ).done(function() { obj.holder.display.line.extend[e](options); } );
  
}

// we can use promises to extend the functionality of the main holder functions
// define any extensions below, then above, at the end of the main function (which, as a display, runs after every execution)
// bind every extension so that the next loop round they get triggered.
// Also, if necessary to bind at init, before the first query fires and returns, set the init to true
// note however if all that is needed is to retrieve some values from remote sources on first execution, that is better done as a value check and a
// call to get those resources the first time the main display function above is called - see display/scotland.js for examples of that, 
// where it retrieves additional map data on first pass
$.fn.holder.display.line.init = false; 
/*$.fn.holder.display.line.extend = {
	execute: function(options) { console.log(options); }
}*/
