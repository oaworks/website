
$.getScript("//static.cottagelabs.com/d3/topojson.v1.min.js");

var _holder_world_topo;
$.fn.holder.display.world = function(obj) {
  var options = obj.holder.options;
  
  if ( !$('div.'+options.class+'.world').length ) {
		obj.append('<div class="' + options.class + ' display world" style="outline:1px solid #ccc;margin-top:20px;height:800px;padding-left:5px;padding-right:5px;"></div>');
		$('div.'+options.class+'.world').append('\
			<svg class="' + options.class + ' world"></svg>'
		);
	}
  if ( !$('svg.'+options.class+'.world').attr('height') ) {
		var dh = $('div.'+options.class+'.world').height() - ($('svg.'+options.class+'.world').offset().top - $('svg.'+options.class+'.world').parent().offset().top);
    $('svg.'+options.class+'.world').attr('height',dh);
  }
	if ( !$('svg.'+options.class+'.world').attr('width') ) {
		var dw = $('div.'+options.class+'.world').width();
    $('svg.'+options.class+'.world').attr('width',dw);
  }
  
	var _holder_world_topo;
  var makemap = function(data) {
    var projection,path,svg,g,draw;
    var updatemap = function() {
      draw(_holder_world_topo,data);
    }

    var tooltip = d3.select("svg.holder.world").append("div").attr("class", "tooltip hidden");

    function setup() {
      var svg = d3.select("svg.holder.world")
      var margin = {top: 0, right: 0, bottom: 0, left: 0};
      var width = +svg.attr("width") - margin.left - margin.right;
      var height = +svg.attr("height") - margin.top - margin.bottom;
      projection = d3.geoMercator()
        .translate([(width/2), (height/1.55)])
        .scale( width / 2 / Math.PI)
        .center([0, 0 ]);

      path = d3.geoPath().projection(projection);
      
      g = svg.append("g");
    }
    if (_holder_world_topo === undefined) setup();

		if (_holder_world_topo) {
			updatemap();
		} else {
			d3.json("//static.cottagelabs.com/maps/world-topo.json", function(error, world) {
				_holder_world_topo = topojson.feature(world, world.objects.countries).features;
				draw(_holder_world_topo);
				updatemap();
			});
		}

    function addpoint(lon,lat) {    
      var gpoint = g.append("g").attr("class", "gpoint");
      var x = projection([lon,lat])[0];
      var y = projection([lon,lat])[1];

      gpoint.append("svg:circle")
        .attr("cx", x)
        .attr("cy", y)
        .attr("class","point")
        .attr("r", 2);
    }

    draw = function(topo,data) {
      var country = g.selectAll(".country").data(topo);
      country.enter().insert("path")
        .attr("class", "country")
        .attr("d", path)
        .attr("id", function(d,i) { return d.id; });

      if (data) {
        data.forEach(function(i) {
          if ( i['location.geo.lat'] && i['location.geo.lon'] ) {
            addpoint(
              i['location.geo.lon'][0],
              i['location.geo.lat'][0]
            );
          } else if ( i.location && i.location.geo && i.location.geo.lat && i.location.geo.lon) {
            addpoint(
              i.location.geo.lon,
              i.location.geo.lat
            );            
          }
        });
      }
    }
    
  }
  makemap(options.records);
  
};
