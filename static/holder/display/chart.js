// a force directed chart visualisation

$.fn.holder.display.chart = function(obj) {
  var options = obj.holder.options;

	$.fn.holder.display.chart.nodesLinks(options.response,options);
	
	if ( !$('div.'+options.class+'.chart').length ) {
		obj.append('<div class="' + options.class + ' chart" style="height:100%;"></div>');
	}
	if ($.fn.holder.display.chart.first) {
		$.fn.holder.display.chart.first = false;
		var svg = d3.select("." + options.class + ".chart").append("svg").attr("width", $("." + options.class + ".chart").width()).attr("height", $("." + options.class + ".chart").height()).call(d3.zoom().on("zoom", function() { g.attr( "transform", d3.event.transform ); }));
		var g = svg.append("g");
		$.fn.holder.display.chart.link = g.append("g").selectAll();
		$.fn.holder.display.chart.node = g.append("g").selectAll();
		$.fn.holder.display.chart.simulation = d3.forceSimulation($.fn.holder.display.chart.nodes)
			//.force("charge", d3.forceManyBody().strength(-1 * $("." + options.class + ".chart").width()/12)) // change 12 to smaller number to start at closer aspect to vid
			.force("link", d3.forceLink($.fn.holder.display.chart.links).distance(-50 + $("." + options.class + ".chart").width()/2))
			//.force("collide",d3.forceCollide().radius(function(d) { return 300; }) )
			.force("center", d3.forceCenter(1200/*$("." + options.class + ".chart").width() / 2*/, $("." + options.class + ".chart").height() / 2))
			//.force("x", d3.forceX())
			//.force("y", d3.forceY())
			.on("tick", $.fn.holder.display.chart.tick);
	}

	function dragstarted(d) {
		if (!d3.event.active) $.fn.holder.display.chart.simulation.alphaTarget(0.3).restart();
		d.fx = d.x;
		d.fy = d.y;
	}
	function dragged(d) {
		d.fx = d3.event.x;
		d.fy = d3.event.y;
	}
	function dragended(d) {
		if (!d3.event.active) $.fn.holder.display.chart.simulation.alphaTarget(0);
		d.fx = null;
		d.fy = null;
	}

	function chart() {
		$.fn.holder.display.chart.node = $.fn.holder.display.chart.node.data($.fn.holder.display.chart.nodes);
		$.fn.holder.display.chart.node = $.fn.holder.display.chart.node.enter()
			.append("g")
            //.on("mouseover", function(d) { $.fn.holder.display.chart.hover(d,true); })
            //.on("mouseout", function(d) { $.fn.holder.display.chart.hover(d,false) })
			//.on("click", function(d) { $.fn.holder.display.chart.click(d); })
			.call(d3.drag()
				.on("start", dragstarted)
				.on("drag", dragged)
				.on("end", dragended))
			.merge($.fn.holder.display.chart.node);
		$.fn.holder.display.chart.node
			.append("foreignObject")
			.attr("x",-100).attr("y",-100).attr("class","slide")
            .html(function(d) { return d.value; });
		$.fn.holder.display.chart.node.exit().remove();

		$.fn.holder.display.chart.link = $.fn.holder.display.chart.link.data($.fn.holder.display.chart.links);
		$.fn.holder.display.chart.link.exit().remove();
		$.fn.holder.display.chart.link = $.fn.holder.display.chart.link.enter().append("line").merge($.fn.holder.display.chart.link);
		$.fn.holder.display.chart.link
		    .attr("class","link")
			.attr("stroke",function(d) { return '#666'; })
			.attr("stroke-width", 0.8);

		$.fn.holder.display.chart.simulation.nodes($.fn.holder.display.chart.nodes);
		$.fn.holder.display.chart.simulation.force("link").links($.fn.holder.display.chart.links);
		$.fn.holder.display.chart.simulation.alpha(1).restart();
		$.fn.holder.display.chart.tick()
	}

	chart();
}

$.fn.holder.display.chart.simulation;
$.fn.holder.display.chart.first = true;

$.fn.holder.display.chart.nodes = [];
$.fn.holder.display.chart.links = [];

$.fn.holder.display.chart.position = function(d,y,t) {
	if (y !== undefined && y !== 'x') {
		y = 'y';
	} else {
		y = 'x';
	}
	if (t === undefined && d.source !== undefined && d.source[y] !== undefined) {
		return d.source[y];
	} else if (t && d.target !== undefined && d.target[y] !== undefined) {
		return d.target[y];
	} else {
		return d[y];
	}
}

$.fn.holder.display.chart.tick = function() {
	$.fn.holder.display.chart.node.attr("transform", function(d) { return "translate(" + [d.x, d.y] + ")"; });
	$.fn.holder.display.chart.link
	    .attr("x1", function(d) { return $.fn.holder.display.chart.position(d); })
		.attr("y1", function(d) { return $.fn.holder.display.chart.position(d,'y'); })
		.attr("x2", function(d) { return $.fn.holder.display.chart.position(d,'x',true); })
		.attr("y2", function(d) { return $.fn.holder.display.chart.position(d,'y',true); });
}


