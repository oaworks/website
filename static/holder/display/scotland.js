
$.getScript("//static.cottagelabs.com/d3/topojson.v1.min.js");

$.fn.holder.display.scotland = function(obj) {
  var options = obj.holder.options;

  var scotland = function(target,locations) {
    if (target === undefined) target = 'body';
    if (fill === undefined) var fill = d3.scaleOrdinal(d3.schemeCategory10);

    var w = $(target).width();
    var h = $(target).height();

    var projection = d3.geoAlbers()
      .center([0.795, 55.79])
      .rotate([4.4, 0])
      .parallels([50, 60])
      .scale(40000)
      .translate([w / 1.6, h / 1.4]);

    var path = d3.geoPath()
        .projection(projection)
        .pointRadius(2);

    var svg = d3.select(target).append("svg:svg").attr("width", w).attr("height", h).attr("pointer-events", "all").append('svg:g').call(d3.zoom().on("zoom", redraw)).append('svg:g');
    svg.append('svg:rect').attr('width', w).attr('height', h).attr('fill', 'transparent');

    // redraw on zoom
    function redraw() {
      svg.attr("transform", d3.event.transform);
    }

    d3.json("//static.cottagelabs.com/maps/scotland/boundaries/all_councils_topo.json", function(error, scotland) {
      var subunits = topojson.feature(scotland, scotland.objects.layer1);

      svg.selectAll(".subunit")
        .data(subunits.features)
        .enter().append("path")
        .attr("class", function(d) { return "subunit " + d.id; })
        //.attr("fill", function(d) { return fill(d.id); })
        .attr("d", path);

      svg.append("path")
        .datum(topojson.mesh(scotland, scotland.objects.layer1, function(a, b) { return a !== b; }))
        .attr("d", path)
        .attr("class", "subunit-boundary");

      svg.selectAll(".subunit-label")
        .data(subunits.features)
        .enter().append("text")
        .attr("class", function(d) { return "subunit-label " + d.id; })
        .attr("transform", function(d) { return "translate(" + path.centroid(d) + ")"; })
        .attr("dy", ".35em")
        .text(function(d) { return d.properties.gss; });

      var mapfilter = function(d) { 
        if (d.type === 'home') {
          $('.'+options.class+'.search').val('post_code:'+d.name.split(' ')[0]).trigger('change');
        } else {
          $('.'+options.class+'.search').val('campus.exact:'+d.name).trigger('change');
        }
      }

      var circles = svg.append("g")
        .attr("class", "circles")
        .selectAll("g")
        .data(locations)
        .enter().append("g")
        .attr("class", function(d) {return d.type === 'home' ? "circle" : "circleCampus"})
        .on("click", mapfilter);

      circles.append("circle")
        .attr("transform", function(d) {
          var location = projection([+d.lon, +d.lat]);
          return "translate(" + location[0]+ "," + location[1]+ ")";
        })
        .attr("r", function(d) {
          return Math.sqrt(parseInt(d.count)*6);
        })
        .append("title")
        .text(function(d) { 
          var t = d.type === 'home' ? 'Home post code prefix' : 'Destination college campus'; 
          t += ': ' + d.name + " (" + d.count + ")\nClick to filter to this "; 
          t += d.type === 'home' ? 'post code': 'campus'; 
          return t; 
        });

      svg.selectAll(".circle-label")
        .data(locations)
        .enter().append("text")
        .attr("class", function(d) { var cl = d.type === 'home' ? 'circle-label' : 'circle-label-campus'; return cl + " " + d.name; })
        .attr("transform", function(d) {
          var location = projection([+d.lon, +d.lat]);
          if (d.type !== 'home') location[1] += .8;
          return "translate(" + location[0]+ "," + location[1]+ ")";
        })
        .attr("dy", ".5em")
        .text(function(d) { return d.name + ' (' + d.count + ')'; });

    });
  }
  
  if ( !$('div.'+options.class+'.scotland').length ) {
		obj.append('<div class="' + options.class + ' display scotland" style="outline:1px solid #ccc;margin-top:20px;height:900px;"></div>');
	}

  var oc = {};
  var cpc = {};
  
	var mapit = function() {
    var locations = [];
    for ( var r in options.response.facets["post code"].terms ) {
      if ( isNaN( parseInt(options.response.facets["post code"].terms[r].term.substring(0,1) ) ) ) {
        var loc = {
          name: options.response.facets["post code"].terms[r].term,
					type: 'home',
          count: options.response.facets["post code"].terms[r].count
        }
        try {
          loc.lat = oc[loc.name].lat;
          loc.lon = oc[loc.name].lon;
          locations.push(loc);
        } catch(err) {}
      }
    }
		var campuscounts = {};
		for ( var m in options.records) {
			var campus = options.records[m].campus;
			campuscounts[campus] = {
				name: campus,
				type: 'dest',
				count: campuscounts[campus] === undefined ? 0 : campuscounts[campus].count + 1
			}
		}
		for ( var cc in campuscounts ) {
			if (cpc[cc]) { // some student campus are not in the current course list
				var pc = cpc[cc].split(' ')[0].toLowerCase();
				campuscounts[cc].lat = oc[pc].lat;
				campuscounts[cc].lon = oc[pc].lon;
				locations.push(campuscounts[cc]);
			}
		}
    $('div.'+options.class+'.scotland').html("");
    scotland('div.'+options.class+'.scotland',locations);
	}

  if (!options.paging) {
    var cpcmap = function() {
      if (JSON.stringify(cpc) === '{}') {
        $.ajax({
          type:'GET',
          url:'https://swapsurvey.org/query/course/_search?q=*&size=1000',
          dataType: 'JSONP',
          success: function(data) {
            for ( var dh in data.hits.hits ) {
              cpc[data.hits.hits[dh]._source.campus] = data.hits.hits[dh]._source.post_code;
            }
            mapit();
          }
        });
      } else {
        mapit();
      }
    }
    if ( JSON.stringify(oc) === '{}' ) {
      $.getScript("//static.cottagelabs.com/maps/scotland/outcodes.js", function() {
        for ( var o in outcodes ) {
          oc[outcodes[o].id] = {
            lat: outcodes[o].location.geo.lat,
            lon: outcodes[o].location.geo.lon,
          }
        }
        cpcmap();
      });
    } else {
      cpcmap();
    }
  }

};