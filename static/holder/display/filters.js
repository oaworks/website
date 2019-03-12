
$.fn.holder.display.filters = function(obj) {
  var options = obj.holder.options;
  if (options.paging) return; // when paging the results, filters don't change, and by default won't even get re-queried, so no point doing anything
  
  if ( !$('.'+options.class+'.filters').length ) obj.prepend('<div class="' + options.class + ' display filters"></div>');
  if ( !options.filters && options.response && ( options.response.facets || options.response.aggs || options.response.aggregations ) ) {
    // assume an ES options.response exists, and extract facets from it
    // or do this as part of default, and just look for options.filters here?
    // also note - if paging/scrolling, will facets change? They should not.
    options.filters = {};
    // also for ES, there could be facets or aggregations (or aggs) - look for both
    if (options.response.aggregations !== undefined) options.response.aggs = options.response.aggregations;
    var aggs = options.response.facets !== undefined ? options.response.facets : options.response.aggs;
    for ( var a in aggs ) {
      var agg = aggs[a];
      if (agg !== undefined && (agg.buckets || agg.terms)) {
        if (options.filters[a] === undefined) options.filters[a] = [];
        if (agg.terms !== undefined) agg.buckets = agg.terms;
        for ( var b in agg.buckets ) {
          var bucket = agg.buckets[b];
          var qa = options.query.aggs !== undefined ? options.query.aggs : (options.query.aggregations !== undefined ? options.query.aggregations : (options.query.facets !== undefined ? options.query.facets : undefined));
          if ( qa !== undefined && qa[a] !== undefined && qa[a].terms !== undefined && qa[a].terms.field !== undefined && ((bucket.key && bucket.doc_count) || (bucket.term !== undefined && bucket.count !== undefined)) ) {
            options.filters[a].push({
              name: a, 
              field: qa[a].terms.field, 
              key: bucket.key !== undefined ? bucket.key : bucket.term,
              value: bucket.doc_count !== undefined ? bucket.doc_count : bucket.count
            });
          }
        }
      }
    }
  }
  if (!options.filters) options.filters = {};

  if ( $('.'+options.class+'.filters').length ) {
    $('.'+options.class+'.filters').html("");
    var fs = 0;
    for ( var o in options.filters ) fs += 1;
    var colw = fs % 4 === 0 ? '3' : '4';
    for ( var ff in options.filters ) {
      if ( options.filters[ff].length ) {
        var disp = '<div class="col-md-' + colw + '"><select style="margin-bottom:3px;" class="form-control holder" do="add" key="';
        disp += options.filters[ff][0].field;
        disp += '" aria-label="filter by ' + ff + '"><option value="">filter by ' + ff + '</option>';
        for ( var fv in options.filters[ff] ) {
          disp += '<option value="' + options.filters[ff][fv].key + '">' + options.filters[ff][fv].key + ' (' + options.filters[ff][fv].value + ')</option>';
        }
        disp += '</select></div>';
        $('.' + options.class + '.filters').append(disp);
      }
    }
  }
}
  

