// a force directed network graph visualisation

$.fn.holder.display.network = function(obj) {
  var options = obj.holder.options;

	$.fn.holder.display.network.nodesLinks(options.response,options);
	
	if ( !$('div.'+options.class+'.network').length ) {
		obj.append('<div class="' + options.class + ' network" style="height:100%;"></div>');
	}
	if ($.fn.holder.display.network.first) {
		$.fn.holder.display.network.first = false;
		var svg = d3.select("." + options.class + ".network").append("svg").attr("width", $("." + options.class + ".network").width()).attr("height", $("." + options.class + ".network").height()).call(d3.zoom().on("zoom", function() { g.attr( "transform", d3.event.transform ); }));
		var g = svg.append("g");
		$.fn.holder.display.network.link = g.append("g").selectAll();
		$.fn.holder.display.network.node = g.append("g").selectAll();
		$.fn.holder.display.network.simulation = d3.forceSimulation($.fn.holder.display.network.nodes)
			.force("charge", d3.forceManyBody().strength(-1 * $("." + options.class + ".network").width()/12)) // change 12 to smaller number to start at closer aspect to vid
			.force("link", d3.forceLink($.fn.holder.display.network.links))//.distance(-50 + $("." + options.class + ".network").width()/4))
			//.force("collide",d3.forceCollide().radius(1 /*function(d) { return d.r + 5; }*/).iterations(2) )
			.force("center", d3.forceCenter($("." + options.class + ".network").width() / 2, $("." + options.class + ".network").height() / 2))
			.force("x", d3.forceX())
			.force("y", d3.forceY())
			.on("tick", $.fn.holder.display.network.tick);
	}

	function dragstarted(d) {
		if (!d3.event.active) $.fn.holder.display.network.simulation.alphaTarget(0.3).restart();
		d.fx = d.x;
		d.fy = d.y;
	}
	function dragged(d) {
		d.fx = d3.event.x;
		d.fy = d3.event.y;
	}
	function dragended(d) {
		if (!d3.event.active) $.fn.holder.display.network.simulation.alphaTarget(0);
		d.fx = null;
		d.fy = null;
	}

	function network() {
		$.fn.holder.display.network.node = $.fn.holder.display.network.node.data($.fn.holder.display.network.nodes);
		$.fn.holder.display.network.node = $.fn.holder.display.network.node.enter()
			.append("g")
            .on("mouseover", function(d) { $.fn.holder.display.network.hover(d,true); })
            .on("mouseout", function(d) { $.fn.holder.display.network.hover(d,false) })
			.on("click", function(d) { $.fn.holder.display.network.click(d); })
			.call(d3.drag()
				.on("start", dragstarted)
				.on("drag", dragged)
				.on("end", dragended))
			.merge($.fn.holder.display.network.node);
		$.fn.holder.display.network.node
			.append("circle")
			.attr("class","node")
			.attr("r", function(d) { return $.fn.holder.display.network.radius(d,options); })
			.attr("fill", function(d) { return $.fn.holder.display.network.fill(d); })
			.style("cursor","pointer")
			.attr("stroke", "#fff")
			.attr("stroke-width", 1)
			.append("svg:title").text(function(d) { return $.fn.holder.display.network.label(d); });

		$.fn.holder.display.network.node
			.append("text")
			.classed("nodeText",true)
			.text(function(d) { return $.fn.holder.display.network.text(d); })
			.attr("dx", 1) // offset from center
    		.attr("dy", 1);

		$.fn.holder.display.network.node.exit().remove();

		$.fn.holder.display.network.link = $.fn.holder.display.network.link.data($.fn.holder.display.network.links);
		$.fn.holder.display.network.link.exit().remove();
		$.fn.holder.display.network.link = $.fn.holder.display.network.link.enter().append("line").merge($.fn.holder.display.network.link);
		$.fn.holder.display.network.link
			.attr("class","link")
			.attr("stroke",function(d) { return '#ccc'; })
			.attr("stroke-width", 0.3)

		$.fn.holder.display.network.simulation.nodes($.fn.holder.display.network.nodes);
		$.fn.holder.display.network.simulation.force("link").links($.fn.holder.display.network.links);
		$.fn.holder.display.network.simulation.alpha(1).restart();
	}

	network();
}

$.fn.holder.display.network.simulation;
$.fn.holder.display.network.first = true;
$.fn.holder.display.network.connect = false; // set this to a list of the nodes to be shown as connected (push them into the links list)

$.fn.holder.display.network.nodes = [];
$.fn.holder.display.network.links = [];

$.fn.holder.display.network.hover = function(nd,hovering) {
	if (hovering === undefined) hovering = true;
	var connect = [];
	$.fn.holder.display.network.link
		.attr("stroke",function(ld) {
			if (hovering) {
				if (nd.index === ld.source.index || nd.index === ld.target.index) {
					if (ld.source.key === 'record') connect.push(ld.source.index);
					if (ld.target.key === 'record') connect.push(ld.target.index);
					return '#666';
				}
			} else {
				return '#ccc';
			}
		})
	if (hovering) {
		$.fn.holder.display.network.link
			.attr("stroke",function(ld) {
				if (connect.indexOf(ld.source.index) !== -1 || connect.indexOf(ld.target.index) !== -1) {
					return '#666';
				}
			})
	}
};

$.fn.holder.display.network.radius = function(d,options) {
	if (d.size === undefined) d.size = 0;
	var r = d3.scaleLinear().domain([0,d3.max($.fn.holder.display.network.nodes,function(d,i) { return d.size; })]).range([5,$("." + options.class + ".network").width()/16]);
	return d.size === 0 ? 0 : r(d.size);
}
var fl = d3.scaleOrdinal(d3.schemeCategory20c);
$.fn.holder.display.network.fill = function(d) { return fl(d.group); }
$.fn.holder.display.network.label = function(d) { return (d.value ? d.value : d.key) + ' (' + d.size + ')'; } // overwrite this one to return text on hover over node (or make it same as above)
$.fn.holder.display.network.text = function(d) {return ''; } // overwrite this to return text to be displayed next to every node

$.fn.holder.display.network.position = function(d,y,t) {
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

$.fn.holder.display.network.tick = function() {
	//$.fn.holder.display.network.node.attr("cx", function(d) { return $.fn.holder.display.network.position(d); })
	//	.attr("cy", function(d) { return $.fn.holder.display.network.position(d,'y'); });
	$.fn.holder.display.network.node.attr("transform", function(d) {
            return "translate(" + [d.x, d.y] + ")";})
	$.fn.holder.display.network.link.attr("x1", function(d) { return $.fn.holder.display.network.position(d); })
		.attr("y1", function(d) { return $.fn.holder.display.network.position(d,'y'); })
		.attr("x2", function(d) { return $.fn.holder.display.network.position(d,'x',true); })
		.attr("y2", function(d) { return $.fn.holder.display.network.position(d,'y',true); });
}

$.fn.holder.display.network.click = function(d) {
	var fq = {term:{}};
	fq.term[d.key] = d.value;
	if ($.fn.holder.options.query.query.filtered.filter === undefined) $.fn.holder.options.query.query.filtered.filter = {};
	if ($.fn.holder.options.query.query.filtered.filter.bool === undefined) $.fn.holder.options.query.query.filtered.filter.bool = {};
	if ($.fn.holder.options.query.query.filtered.filter.bool.must === undefined) $.fn.holder.options.query.query.filtered.filter.bool.must = [];
	$.fn.holder.options.query.query.filtered.filter.bool.must.push(fq);
	$.fn.holder.options.execute();
}

$.fn.holder.display.network.nodesLinks = function(data,options) {
	if (!options.paging) {
		$.fn.holder.display.network.nodes = [];
		$.fn.holder.display.network.links = [];
	}
	// TODO what about when paging backwards, how does it affect the result set?
	for ( var ri in data.hits.hits ) {
		var rec = data.hits.hits[ri]._source !== undefined ? data.hits.hits[ri]._source : data.hits.hits[ri].fields;
		rec.key = 'record';
		rec.group = data.hits.hits[ri]._type; // TODO need some way to set the key, value and size of these objects, based on their input data, if desired
		rec.size = 1;
		$.fn.holder.display.network.nodes.push(rec);
		if (!$.fn.holder.display.network.first) {
			for ( var o in rec ) {
				for ( var nx = 0; nx < $.fn.holder.display.network.nodes.length; nx++ ) {
					var cr = typeof rec[o] === 'string' ? [rec[o]] : rec[o]; // what about nested objects? should prob use dotindex...
					if ($.fn.holder.display.network.nodes[nx].key === o && cr.indexOf($.fn.holder.display.network.nodes[nx].value) !== -1) {
						$.fn.holder.display.network.links.push({"source":$.fn.holder.display.network.nodes.length-1,"target":nx});
					}
				}
			}
		}
	}
	for ( var i in data.aggregations ) {
		var ky = undefined;
		try {
			var ags = $.fn.holder.options.aggregations !== undefined ? $.fn.holder.options.aggregations : $.fn.holder.options.aggs !== undefined ? $.fn.holder.options.aggs : $.fn.holder.options.facets;
			var ky = ags[i].term !== undefined ? ags[i].term.field : ags[i].terms.field;
		} catch(err) {}
		var arrs = data.aggregations[i].buckets;
		for ( var bi in arrs ) {
			var arr = { key: i, value: arrs[bi].key, size: arrs[bi].doc_count, group: i }
			$.fn.holder.display.network.nodes.push(arr);
			if ( $.fn.holder.display.network.connect !== false ) {
				for ( var x = 0; x < $.fn.holder.display.network.nodes.length; x++ ) {
					if ($.fn.holder.display.network.connect.indexOf(i) !== -1 && ( $.fn.holder.display.network.nodes[x][i] === arr.value || ( $.fn.holder.display.network.nodes[x][i] !== undefined && $.fn.holder.display.network.nodes[x][i].indexOf(arr.value) !== -1 ) || (ky !== undefined && ($.fn.holder.display.network.nodes[x][ky] === arr.value || ( $.fn.holder.display.network.nodes[x][ky] !== undefined && $.fn.holder.display.network.nodes[x][ky].indexOf(arr.value) !== -1 ))))) {
						$.fn.holder.display.network.links.push({"source":$.fn.holder.display.network.nodes.length-1,"target":x});
					}
				}
			}
		}
	}
}

