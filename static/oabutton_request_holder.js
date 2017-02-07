
$.fn.holder.use.oabutton = {
  url: "https://api.openaccessbutton.org/requests",
  pushstate: false,
  sticky: true,
  datatype: 'JSON',
  size:500,
  sort:[{createdAt:'desc'}],
  fields: ['status','type','user.profession','user.affiliation','_id','url','created_date','createdAt','title','email','user.username','location.geo.lat','location.geo.lon','story','count'],
  facets: {
    status: { terms: { field: "status.exact" } },
    type: { terms: { field: "type.exact" } },
    //plugin: { terms: { field: "plugin.exact", size: 100 } },
    "user": { terms: { "field": "user.username.exact", size: 1000 } },
    "author email": { terms: { field: "email.exact", size: 1000 } },
    keyword: { terms: { field: "keywords.exact", size: 1000 } },
    journal: { terms: { field: "journal.exact", size: 1000 } }
  },
  
  placeholder: function() {
    var options = $(this).holder.options;
    var found = '';
    found += options.query.size < options.response.hits.total ? options.query.from + options.query.size : options.response.hits.total;
    found += ' of ' + options.response.hits.total;
    found += ' open access button requests';
    $('input.' + options.class + '.search').val("").attr('placeholder',found);
  },

  record: function(rec,idx) {
    var sts = {
      moderate: {text:'Awaiting moderation - nearly ready :)',color:'#ddd',highlight:'grey'},
      help: {text:'We need more info - can you help?',color:'#ddd',highlight:'#f04717'},
      progress: {text:'In progress - read more, support it, provide it!',highlight:'#212f3f'},
      received: {text:'Success! This item has made available!',highlight:'#5cb85c',color:'#dcefdc'},
      refused: {text:'Refused - can you help us try again?',highlight:'#d9534f',color:'#f1c2c0'}
    }
    var color = rec.status && sts[rec.status] && sts[rec.status].color ? sts[rec.status].color : '#eee';
    var status = rec.status && sts[rec.status] && sts[rec.status].text ? sts[rec.status].text : rec.status;
    var highlight = rec.status && sts[rec.status] && sts[rec.status].highlight ? sts[rec.status].highlight : '#eee';
    var text = rec.status && sts[rec.status] && sts[rec.status].highlight ? sts[rec.status].highlight : 'blue';
    var re = '<div class="well" style="border-width:3px;border-color:' + highlight + ';margin:30px auto 0px auto;background-color:' + color + '">';
    re += '<p><b>';
    if (rec.type && rec.type === 'data') re += 'Data for ';
    re += '<a href="/request/' + rec._id + '">' + rec.title + '</a></b></p>';
    re += '<blockquote>';
    re += '<a style="color:#383838;" href="/request/' + rec._id + '">' + rec.story + '</a><cite>';
    re += 'from ' + rec['user.username'];
    if (rec['user.profession'] && rec['user.profession'] !== 'Other') re += ', ' + rec['user.profession'];
    if (rec['user.affiliation'] && rec['user.affiliation'].length > 1) re += ' at ' + rec['user.affiliation'];
    re += rec.created_date ? ', on ' + rec.created_date.split(' ')[0].split('-').reverse().join('/') : '';
    if (rec.count && rec.count > 1) re += '<br>' + rec.count + ' people support this request';
    re += '<br><a href="/request/' + rec._id + '" style="color:' + text + ';">' + status + '</a></cite>';
    re += '</blockquote></div>';
    return re;
  },
  transform: function(rec) {
    var res = rec.fields;
    if (res.createdAt) res.createdAt = res.createdAt[0];
    if (res.type) res.type = res.type[0];
    if (res['user.profession']) res['user.profession'] = res['user.profession'][0];
    if (res['user.affiliation']) res['user.affiliation'] = res['user.affiliation'][0];
    if (res['status']) res['status'] = res['status'][0];
    if (res.created_date) res.created_date = res.created_date[0];
    return res;
  },
  review: function(data) {
    var options = $(this).holder.options;
    if (data === undefined) data = options.response;
    var fromclass='.from' + options.query.from;
    if (options.paging) {
      $('.' + options.class + '.results').last().after('<div class="' + options.class + ' additional results ' + fromclass.replace('.','') + '"></div>');
      if (!options.scroll) $('div.' + options.class + '.results').not(fromclass).hide();
    } else {
      options.records = [];
      $('div.' + options.class + '.additional.results').remove();
      $('div.' + options.class + '.results').show().html('');
    }
    var results = data.hits.hits;
    for ( var r in results ) {
      var rec = options.transform(results[r]);
      options.records.push(rec);
      $('.' + options.class + '.results'+fromclass).append(options.record(rec,r));
    }
    $('.requestcount').html(options.response.hits.total);
  },
  
  instruct: function(e) {
    if (e) e.preventDefault();
    var options = $(this).holder.options;
    var which = $(e.target).attr('val');
    if (which !== 'search') $('.holder.options').hide();
    if (which === 'help') {
      $('select.holder[key="status.exact"]').val('help').trigger('change');
      //$('input.holder.search').val('status.exact:help').trigger('change');
    } else if (which === 'respond') {
      $('.holder[do="remove"]').trigger('click');
      $('select.holder[key="status.exact"]').val('progress').trigger('change');
    } else if (which === 'support') {
      $('.holder[do="remove"]').trigger('click');      
    } else if (which === 'request') {
      $('.holder.results').hide();
    }
    $('.instruct').hide();
    $('.instruct.'+which).show();
  }

};

