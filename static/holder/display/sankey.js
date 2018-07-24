
$.getScript("//static.cottagelabs.com/d3/sankey.js");

$.fn.holder.display.sankey = function(obj) {
	var options = obj.holder.options;

	var sankey = function(element,data,flows,fields) {

		// calculates nodes and links from an ES response set with hits and aggregations
		var setnodesandlinks = function(data,fields) {
			var nodepositions = {};
			var nodecounts = {};
			var visdata = {nodes:[],links:[]}; //,linksindex:{}};
			for ( var i in data ) {
				var rec = data[i];
				for ( var v in rec ) {
					if (fields === undefined || fields.indexOf(v) !== -1) {
						var val = rec[v];
						if (val) {
							var vpos = undefined;
							if (nodepositions[v+val] === undefined) {
								visdata.nodes.push({name:val,type:v});
								vpos = visdata.nodes.length-1;
								nodepositions[v+val] = vpos;
							} else {
								vpos = nodepositions[v+val];
							}
							if (flows === undefined || flows[v] !== undefined) {
								for ( var vv in rec ) {
									if (fields === undefined || fields.indexOf(vv) !== -1) {
										if ( vv !== v ) {
											var vval = rec[vv];
											if (vval) {
												var vvpos = undefined;
												if (nodepositions[vv+vval] === undefined) {
													visdata.nodes.push({name:vval,type:vv});
													vvpos = visdata.nodes.length-1;
													nodepositions[vv+vval] = vvpos;
												} else {
													vvpos = nodepositions[vv+vval];
												}
												if ( flows === undefined || ( flows[v] !== undefined && flows[v].indexOf(vv) !== -1 ) ) {                 
													var ref = [v,vv].sort()[0] === v ? vpos + '_' + vvpos : vvpos + '_' + vpos;
													if (nodecounts[ref] === undefined) {
														nodecounts[ref] = 1;
													} else {
														nodecounts[ref] += 1;
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
			for ( var nc in nodecounts ) {
				var parts = nc.split('_');
				visdata.links.push({source:parseInt(parts[0]),target:parseInt(parts[1]),value:nodecounts[nc]});
			}
			return visdata;
		}

		var visdata = setnodesandlinks(data,fields);

		var margin = {top: 0, right: 1, bottom: 50, left: 1},
      width = +$(element).attr("width") - margin.left - margin.right,
      height = +$(element).attr("height") - margin.top - margin.bottom;

		var formatNumber = d3.format(",.0f"),
				format = function(d) { return formatNumber(d); },
				color = d3.scaleOrdinal(d3.schemeCategory10);

		var svg = d3.select(element)
				.attr("width", width + margin.left + margin.right)
				.attr("height", height + margin.top + margin.bottom)
			.append("g")
				.attr("transform", "translate(" + margin.left + "," + margin.top + ")");

		var sankey = d3.sankey()
				.nodeWidth(15)
				.nodePadding(10)
				.size([width, height]);

		var path = sankey.link();

		sankey
				.nodes(visdata.nodes)
				.links(visdata.links)
				.layout(32);

		var link = svg.append("g").selectAll(".link")
				.data(visdata.links)
			.enter().append("path")
				.attr("class", "link")
				.attr("d", path)
				.style("stroke-width", function(d) { return Math.max(1, d.dy); })
				.sort(function(a, b) { return b.dy - a.dy; });

		link.append("title")
				.text(function(d) {return 'FROM ' + d.source.type.replace(/.*\./,'') + ': ' + d.source.name + ' (' + d.source.value + ')\nTO ' + d.target.type.replace(/.*\./,'') + ': ' + d.target.name + ' (' + d.target.value + ')\ncount: ' + d.value; });

		var node = svg.append("g").selectAll(".node")
				.data(visdata.nodes)
			.enter().append("g")
				.attr("class", "node")
				.attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })
			.call(d3.drag()
				.subject(function(d) { return d; })
				.on("start", function() { 
				this.parentNode.appendChild(this); })
				.on("drag", dragmove));

		node.append("rect")
				.attr("height", function(d) { return d.dy; })
				.attr("width", sankey.nodeWidth())
				.style("fill", function(d) { return d.color = color(d.name.toString().toLowerCase().replace(/[^a-z0-9]/, "")); })
				.style("stroke", function(d) { return d3.rgb(d.color).darker(2); })
			.append("title")
				.text(function(d) { return d.type.replace(/.*\./,'') + ': ' + d.name + "\ncount: " + format(d.value); });

		node.append("text")
				.attr("x", -6)
				.attr("y", function(d) { return d.dy / 2; })
				.attr("dy", ".35em")
				.attr("text-anchor", "end")
				.attr("transform", null)
				.text(function(d) { return d.name; })
			.filter(function(d) { return d.x < width / 2; })
				.attr("x", 6 + sankey.nodeWidth())
				.attr("text-anchor", "start");

		function dragmove(d) {
			d3.select(this).attr("transform", 
				"translate(" + (
					d.x = Math.max(0, Math.min(width - d.dx, d3.event.x))
				) + "," + (
					d.y = Math.max(0, Math.min(height - d.dy, d3.event.y))
				) + ")");
			sankey.relayout();
			link.attr("d", path);
		}
	}

	var flows = {};
	var flowfields = [];
	var changeflow = function() {
		flows = {};
		flowfields = [];
		$('select.'+options.class+'.sankey').each(function(i) {
			if ( $(this).val() ) {
				flowfields.push($(this).val());
				if ( flowfields.length > 1) flows[flowfields[flowfields.length-2]] = [flowfields[flowfields.length-1]];
			} 
		});
		if ( flowfields.length > 1) {
			$('svg.'+options.class+'.sankey').html("");
			sankey('svg.'+options.class+'.sankey',options.records,flows,flowfields);
		}
	}

  if ( !$('div.'+options.class+'.sankey').length ) {
		obj.append('<div class="' + options.class + ' display sankey" style="outline:1px solid #ccc;margin-top:20px;height:800px;padding-left:5px;padding-right:5px;"></div>');
		$('div.'+options.class+'.sankey').append('\
			<div class="' + options.class +  ' sankeycontrols"></div> \
			<svg class="' + options.class + ' sankey"></svg>'
		);
		var dh = $('div.'+options.class+'.sankey').height() - ($('svg.'+options.class+'.sankey').offset().top - $('svg.'+options.class+'.sankey').parent().offset().top);
		var dw = $('div.'+options.class+'.sankey').width();
		if ( !$('svg.'+options.class+'.sankey').attr('height') ) $('svg.'+options.class+'.sankey').attr('height',dh);
		if ( !$('svg.'+options.class+'.sankey').attr('width') ) $('svg.'+options.class+'.sankey').attr('width',dw);
	}
	
	if (!options.paging) {
		// TODO this should probably build from an analysis of the keys in the records, not from options.fields
		$('div.'+options.class+'.sankeycontrols').html("");
		var howmany = options.fields.length > 5 ? 5 : options.fields.length;
		for ( var i = 0; i < howmany; i++ ) {
			var selector = '<select class="form-control ' + options.class + ' sankey" style="width:19%;margin-top:5px;margin-bottom:5px;margin-right:3px;display:inline-block;">';
			selector += '<option value="">Select flow...</option>';
			for ( var f in options.fields ) {
				var whatselect = i === parseInt(f) && i < 2 ? ' selected="selected"' : '';
				selector += '<option value="' + options.fields[f] + '"' + whatselect + '>flow: ' + options.fields[f] + '</option>';
			}
			selector += '</select>';
			$('div.'+options.class+'.sankeycontrols').append(selector);
		}
		$('select.'+options.class+'.sankey').bind('change',changeflow);
	}

	changeflow();
	
}
