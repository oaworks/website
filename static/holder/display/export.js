
$.fn.holder.display.export = function(obj) {
  var options = obj.holder.options;
  
  if ( !$('.'+options.class+'.export').length ) {
    if ( $('.'+options.class+'.options').length ) {
      $('.'+options.class+'.options').append('<div class="' + options.class + ' display export"></div>');
    } else {
     obj.append('<div class="' + options.class + ' display export"></div>');
    }
  }
    
  $('.'+options.class+'.export').html("");
  
  var btns = '<div class="input-group"> \
    <div class="input-group-btn"> \
      <button class="btn btn-disabled btn-title">From</button> \
    </div> \
    <input type="text" class="form-control holder from" do="from" style="height:36px;"> \
    <div class="input-group-btn"> \
      <button class="btn btn-disabled btn-title" style="border-radius:0px;">To</button> \
    </div> \
    <input type="text" class="form-control holder to" do="to" style="height:36px;margin-left:-2px;"> \
    <div class="input-group-btn"> \
      <button class="btn btn-disabled btn-title" style="border-radius:0px;margin-left:-2px;">Download</button> \
      <button type="button" class="btn btn-info ' + options.class + ' export" do="export" val="json">JSON</button> \
      <button type="button" class="btn btn-primary ' + options.class + ' export" do="export" val="csv">CSV</button> \
    </div> \
  </div>';

  $('.'+options.class+'.export').append(btns);
  $('.' + options.class + '.from').val(options.query.from);
  $('.' + options.class + '.to').val(options.query.from + options.query.size);
  
}
  

