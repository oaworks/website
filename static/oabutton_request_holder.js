
$.fn.holder.use.oabutton = {
  url: "https://api.openaccessbutton.org/requests",
  //pushstate: false,
  sticky:true,
  datatype: 'JSON',
  size:500,
  scroll:true,
  sort:[{createdAt:'desc'}],
  fields: ['status','type','user.profession','user.affiliation','_id','url','created_date','createdAt','title','email','user.username','user.firstname','user.email','location.geo.lat','location.geo.lon','story','count'],
  facets: {
    status: { terms: { field: "status.exact" } },
    user: { terms: { field: "user.profession.exact" } },
    type: { terms: { field: "type.exact" } },
    //plugin: { terms: { field: "plugin.exact", size: 100 } },
    keyword: { terms: { field: "keywords.exact", size: 1000 } },
    journal: { terms: { field: "journal.exact", size: 1000 } }
  },

  ranges: {
    createdAt: {
      name: 'Created',
      date: {
        value: function(date) {
          if (typeof date === 'string') date = parseInt(date);
          var dv = date.toString().length > 10 ? Math.floor(date/1000) : date;
          dv = dv - dv%86400; // also converts to start of current day
          return dv;
        },
        display: function(date) {
          if (typeof date === 'string') date = parseInt(date);
          if (date.toString().length <= 10) date = date * 1000;
          var d = new Date(date);
          var dd = d.getDate() + '/' + (d.getMonth()+1) + '/' + d.getFullYear();
          return dd;
        },
        submit: function(date,max) {
          if (typeof date === 'string') date = parseInt(date);
          var ds = date.toString().length <= 10 ? date * 1000 : date;
          if (max) ds += 86400; // to make sure we get things created during the max day
          return ds;
        }
      },
      step: 86400,
      min: 1356998400
    }
  },

  placeholder: function() {
    var options = $(this).holder.options;
    $('input.' + options.class + '.search').val("").attr('placeholder',"Search for requests you care about");
  },

  record: function(rec,idx) {
    var sts = {
      moderate: {text:'Awaiting moderation',color:'#eee',highlight:'grey'},
      help: {text:'Information needed - can you help?',color:'#fbdad0',highlight:'#f04717'},
      progress: {text:'In progress - join and share the request',highlight:'grey',color:'white'},
      received: {text:'Success! This item has been made available!',highlight:'#5cb85c',color:'#dcefdc'},
      refused: {text:'Refused',highlight:'#d9534f',color:'#f1c2c0'},
      closed: {text:'Closed - this request could not be completed',highlight:'grey',color:'#eee'}
    }
    var color = rec.status && sts[rec.status] && sts[rec.status].color ? sts[rec.status].color : '#eee';
    var status = rec.status && sts[rec.status] && sts[rec.status].text ? sts[rec.status].text : rec.status;
    var highlight = rec.status && sts[rec.status] && sts[rec.status].highlight ? sts[rec.status].highlight : '#eee';
    var text = rec.status && sts[rec.status] && sts[rec.status].highlight ? sts[rec.status].highlight : 'blue';
    var re = '<div class="well" style="margin:30px auto 0px auto;background-color:' + color + '">';
    re += '<p>';
    if (rec.type && rec.type === 'data') re += 'Data for ';
    re += '<b><a href="/request/' + rec._id + '" style="word-wrap:break-word;overflow-wrap:break-word;">';
    re += rec.title ? rec.title : rec.url;
    re += '</a></b></p>';
    re += '<p><a href="/request/' + rec._id + '" style="color:' + text + ';">' + status + '</a></p>';
    if (rec.story && ( parseInt(rec.rating) >= 3 || rec.rating === undefined ) ) re += '<p style="padding:10px 0px 10px 30px;"><a style="color:#383838;font-style:italic;font-weight:bold;font-size:1.2em;" href="/request/' + rec._id + '">' + rec.story + '</a></p>';
    re += '<p>Requested ';
    var un = rec['user.firstname'] ? rec['user.firstname'] : rec['user.username'];
    if (!un) un = rec['user.email'];
    re += un ? 'by ' + un : '';
    if (rec['user.profession'] && rec['user.profession'] !== 'Other') re += ', ' + rec['user.profession'];
    if (rec['user.affiliation'] && rec['user.affiliation'].length > 1) re += ' at ' + rec['user.affiliation'];
    re += rec.created_date ? ' on ' + rec.created_date.split(' ')[0].split('-').reverse().join('/') : '';
    re += '</p>';
    if (rec.count && rec.count > 1) re += '<p>' + rec.count + ' people support this request</p>';
    re += '</div>';
    return re;
  },
  transform: function(rec) {
    var res = rec.fields;
    if (res.createdAt) res.createdAt = res.createdAt[0];
    if (res.type) res.type = res.type[0];
    if (res['user.profession']) res['user.profession'] = res['user.profession'][0];
    if (res['user.affiliation']) res['user.affiliation'] = res['user.affiliation'][0];
    if (res.status) res.status = res.status[0];
    if (res.title) res.title = res.title[0];
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
  }

};
