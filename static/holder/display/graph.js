
// this graph display assumes the default search display has already tidily created options.results

$.fn.holder.display.graph = function(obj) {
  var options = obj.holder.options;
  
	var notshowing = [];
	var data, graphwhat, graphgroup;
	var chartit = function(e) {
		$('svg.' + options.class + '.graph').html("");
		notshowing = [];
		data = [];
		data.columns = [];
		var counts = {};
		graphwhat = $('.'+options.class+'.graphcontrol.graphwhat').val();
		graphgroup = $('.'+options.class+'.graphcontrol.graphgroup').val();
		if (graphgroup === '') graphgroup = graphwhat;
		// TODO do something about when things are lists
		for ( var d in options.records ) {
			var dd = options.records[d];
			var graphgroupshowselected = [];
			$('.'+options.class+'.graphshow').each(function () {
				if ($(this).attr('graphshowing')) graphgroupshowselected.push($(this).attr('graphshow'));
			});
			if ( ( graphgroupshowselected.length === 0 || graphgroupshowselected.indexOf(dd[graphgroup]) !== -1 ) && dd[graphwhat] ) {
				if ( !dd[graphgroup] ) dd[graphgroup] = 'UNKNOWN';
				if (counts[dd[graphgroup]] === undefined) {
					counts[dd[graphgroup]] = {};
					counts[dd[graphgroup]][graphgroup] = dd[graphgroup];
				}
				if (counts[dd[graphgroup]][dd[graphwhat]] === undefined) counts[dd[graphgroup]][dd[graphwhat]] = 0;
				counts[dd[graphgroup]][dd[graphwhat]] += 1;
				if (data.columns.indexOf(dd[graphwhat]) === -1 && dd[graphwhat] !== 'UNKNOWN') data.columns.push(dd[graphwhat]);
			}
		}
		for ( var c in counts ) data.push(counts[c]);
    chart();
	}  

  if ( !$('div.'+options.class+'.graph').length ) {
		obj.append('<div class="' + options.class + ' display graph" style="outline:1px solid #ccc;margin-top:20px;height:800px;padding-left:5px;padding-right:5px;"></div>');
	}
  if ( !$('div.'+options.class+'.graphcontrols').length ) {
		$('div.'+options.class+'.graph').prepend('\
			<div class="' + options.class +  ' graphcontrols"> \
				<select class="form-control ' + options.class + ' graphcontrol graphwhat" style="width:200px;margin-top:5px;margin-bottom:5px;display:inline-block;"> \
				</select> \
				<select class="form-control ' + options.class + ' graphcontrol graphgroup" style="width:200px;margin-top:5px;margin-bottom:5px;display:inline-block;"> \
				</select> \
			</div>'
		);
	}
  if ( !$('svg.'+options.class+'.graph').length ) $('div.'+options.class+'.graph').append('<svg class="' + options.class + ' graph"></svg>');
	if ( $('select.'+options.class+'.graphcontrol').length ) $('select.'+options.class+'.graphcontrol').on('change',chartit);
	if ( !$('svg.'+options.class+'.graph').attr('height') ) {
		var dh = $('div.'+options.class+'.graph').height() - ($('svg.'+options.class+'.graph').offset().top - $('svg.'+options.class+'.graph').parent().offset().top) - 40;
		$('svg.'+options.class+'.graph').attr('height',dh);
	}
	if ( !$('svg.'+options.class+'.graph').attr('width') ) {
		var dw = $('div.'+options.class+'.graph').width();
		$('svg.'+options.class+'.graph').attr('width',dw);
	}
	
	if (!options.paging) {
		// TODO this should probably build from an analysis of the keys in the records, not from options.fields
		// TODO what about a no-grouping option...
		$('.'+options.class+'.graphcontrol.graphgroup').append('<option value="">group by: (no group)</option>');
		for ( var f in options.fields ) {
			var whatselect = f === "0" ? ' selected="selected"' : '';
			$('.'+options.class+'.graphcontrol.graphwhat').append('<option value="' + options.fields[f] + '"' + whatselect + '>graph: ' + options.fields[f] + '</option>');
			$('.'+options.class+'.graphcontrol.graphgroup').append('<option value="' + options.fields[f] + '">group by: ' + options.fields[f] + '</option>');
		}
	}

	var chartshow = function(i) {
		var show = $(this).attr('graphshow');
		if (notshowing.indexOf(show) === -1) {
			$(this).attr('refill',$(this).attr('fill')).attr('fill',"white");
			$('.'+options.class+'[datashow="' + show + '"]').hide();
			notshowing.push(show);
		} else {
			$(this).attr('fill',$(this).attr('refill'));
			$('.'+options.class+'[datashow="' + show + '"]').show()
			notshowing.splice(notshowing.indexOf(show),1);
		}
	}
	
  var chart = function() {

    var svg = d3.select('svg.' + options.class + '.graph'),
      margin = {top: 100, right: 100, bottom: 30, left: 40},
      width = +svg.attr("width") - margin.left - margin.right,
      height = +svg.attr("height") - margin.top - margin.bottom,
      g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		
    var x0 = d3.scaleBand()
      .rangeRound([0, width])
      .paddingInner(0.1);

    var x1 = d3.scaleBand()
      .padding(0.05);

    var y = d3.scaleLinear()
      .rangeRound([height, 0]);

    var keys = data.columns;
	  var fill = keys === undefined || keys.length < 10 ? d3.scaleOrdinal(d3.schemeCategory10) : d3.scaleOrdinal(d3.schemeCategory20c);

    x0.domain(data.map(function(d) { return d[graphgroup]; }));
    x1.domain(keys).rangeRound([0, x0.bandwidth()]);
    y.domain([0, d3.max(data, function(d) { return d3.max(keys, function(key) { return d[key]; }); })]).nice();

    g.append("g")
      .selectAll("g")
      .data(data)
      .enter().append("g")
        .attr("transform", function(d) { return "translate(" + x0(d[graphgroup]) + ",0)"; })
      .selectAll("rect")
      .data(function(d) { return keys.map(function(key) { var val = d[key] ? d[key] : 0; return {key: key, value: val}; }); })
      .enter().append("rect")
        .attr("x", function(d) { return graphwhat === graphgroup ? x1(keys[0]) : x1(d.key); })
        .attr("y", function(d) { return y(d.value); })
        .attr("width", function(d) {return graphwhat === graphgroup ? x1.bandwidth() * data.columns.length : x1.bandwidth(); })
        .attr("height", function(d) { return height - y(d.value); })
				.attr("class",options.class)
        .attr("datashow", function(d) { return d.key; })
        .attr("fill", function(d) { return fill(d.key); })
      .append("title")
        .text(function(d) { return d.key + "\n" + d.value; });

    g.append("g")
        .attr("class", "axis")
        .attr("transform", "translate(0," + height + ")")
        .call(d3.axisBottom(x0));

    g.append("g")
        .attr("class", "axis")
        .call(d3.axisLeft(y).ticks(10, "s").tickSize(-(width), 0, 0).tickSizeOuter(0));

    var legend = g.append("g")
        .attr("font-family", "sans-serif")
        .attr("font-size", 10)
        .attr("text-anchor", "end")
      .selectAll("g")
      .data(keys.slice().reverse())
      .enter().append("g")
        .attr("transform", function(d, i) { return "translate(100," + (-100 + i * 20) + ")"; });

    legend.append("circle")
      .attr("r", 8)
      .attr("cx", width - 10)
      .attr("cy", 10)
      .attr("fill", fill)
      .attr("stroke", fill)
      .attr("stroke-width", "2px")
			.attr("graphshow",function(d) { return d; })
			.on("click",chartshow)
			.style('cursor', 'pointer' )
			.append("title")
				.text("click to show/hide");

    legend.append("text")
      .attr("x", width - 24)
      .attr("y", 9.5)
      .attr("dy", "0.32em")
      .text(function(d) { return d; });
  }
		
	chartit();
  
}
