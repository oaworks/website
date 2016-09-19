
jQuery(document).ready(function() {

  var makemap = function() {
    $('#odbpositioner').html('<div style="position:relative;top:0;left:0;z-index:1000;"> \
    <p style="text-align:center;"> \
      <a href="https://opendatabutton.org/story" style="font-weight:bold;color:#212f3f;"> \
        opendatabutton.org \
        <span id="odbmapcount"></span> \
        people need access to data. Can you help? \
      </a> \
    </p> \
  </div> \
  <div id="mapspace" style="width:100%;height:100%;position:relative;top:-43px;left:0;z-index:1;"></div>');
    
    var topo,projection,path,svg,g,draw;

    var updatemap = function(data) {
      $('#odbmapcount').html(data.hits.total);
      draw(topo,data);
    }

    var getdata = function() {
      var qry = {
        "size":100000, 
        "query": {
          filtered: {
            query: {
              bool: {
                must: []
              }
            },
            filter: {
              bool: {
                must:[{term:{'type.exact':'article'}}]
              }
            }
          }
        }, 
        "fields": ["location.geo.lat","location.geo.lon"] 
      }
      $.ajax({
        type: 'GET',
        url: '//api.opendatabutton.org/query/blocked?source=' + JSON.stringify(qry),
        dataType: 'JSON',
        success: updatemap
      });
    }

    var width = document.getElementById('mapspace').offsetWidth;
    var height = document.getElementById('mapspace').offsetHeight;

    var tooltip = d3.select("#mapspace").append("div").attr("class", "tooltip hidden");

    function setup(width,height) {
      projection = d3.geo.mercator()
        .translate([(width/2), (height/1.55)])
        .scale( width / 2 / Math.PI)
        .center([0, 0 ]);

      path = d3.geo.path().projection(projection);

      svg = d3.select("#mapspace").append("svg")
        .attr("width", width)
        .attr("height", height)
        .append("g");

      g = svg.append("g");
    }
    setup(width,height);

    d3.json("//static.cottagelabs.com/maps/world-topo.json", function(error, world) {
      topo = topojson.feature(world, world.objects.countries).features;
      draw(topo);
      getdata();
    });

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

      //add points and repo suggestions
      if ( data ) {
        data.hits.hits.forEach(function(i){
          if ( i.fields && i.fields['location.geo.lat'] && i.fields['location.geo.lon'] ) {
            addpoint(
              i.fields['location.geo.lon'][0],
              i.fields['location.geo.lat'][0]
            );
          }
        });
      }
    }
    
  }
  makemap();
  
});
