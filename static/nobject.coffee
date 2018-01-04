
#a library for managing reading writing and saving of objects

@dot = (obj, key, value, del) ->
  if typeof key is 'string'
    return dot obj, key.split('.'), value, del
  else if key.length is 1 and (value? or del?)
    if del is true or value is '$DELETE'
      if obj instanceof Array
        obj.splice key[0], 1
      else
        delete obj[key[0]]
      return true;
    else
      obj[key[0]] = value # TODO see below re. should this allow writing into multiple sub-objects of a list?
      return true
  else if key.length is 0
    return obj
  else
    if not obj[key[0]]?
      if false
        # check in case obj is a list of objects, and key[0] exists in those objects
        # if so, return a list of those values.
        # Keep order of the list? e.g for objects not containing the key, output undefined in the list space where value would have gone?
        # and can this recurse further? If the recovered items are lists or objecst themselves, go further into them?
        # if so, how would that be represented?
        # and is it possible for this to work at all with value assignment?
      else if value?
        obj[key[0]] = if isNaN(parseInt(key[0])) then {} else []
        return dot obj[key[0]], key.slice(1), value, del
      else
        return undefined
    else
      return dot obj[key[0]], key.slice(1), value, del

@nobject = (obj,oelem,opts) ->
  if typeof oelem is 'object'
    opts = oelem
  else if typeof oelem is 'string'
    opts ?= {}
    opts.element = oelem
  this._object = obj
  this._debug = opts.debug ?= noddy?.debug
  this._element = opts.element ?= 'body' # if this is called on an element in the jquery way, can we get the element that way? (without bothering making this a whole jquery thing too)
  this._api = opts.api ?= if noddy? then noddy.api + '/accounts' else window.location.href.split('?')[0].split('#')[0]
  this._apikey = opts.apikey ?= noddy?.apikey
  this._original = JSON.parse(JSON.stringify(obj))
  this._changes = if opts.changes ?= true then {} else false
  this._auto = opts.auto ?= true
  this._keys = opts.keys
  this._poll = opts.poll ?= false
  # TODO should have an option of defaults that controls starting values and what can be chosen values for keys where the value should be controlled
  # TODO should also have a way of getting suggestions for fields that require them
  if typeof this._object is 'string'
    this._url = this._object if this._object.indexOf('http') is 0
    this.retrieve(opts.display,opts.populate,opts.poll)
  else
    this._url = opts.url
    this.display() if opts.display ?= true
    this.populate() if opts.populate ?= true
    this.poll() if this._poll
  this.watch()
  $(this._element).on('click','.nobject.checker',(e) -> e.preventDefault(); $(this).find('input').prop('checked',!$(this).find('input').is(':checked')).trigger('change'); )
  if this._debug
    console.log 'Nobject is configured', obj, opts
  return

try noddy.nobject = nobject

nobject.prototype.update = (dotkey,val,populate) ->
  console.log('Nobject updating ', dotkey, val) if this._debug
  this._changes[dotkey] = val if this._changes isnt false
  dot this._object, dotkey, val
  this.populate(dotkey, val) if populate isnt false
  if this._auto
    $(this._element + ' [nobject="' + dotkey + '"]').addClass('has-success')
    $(this._element + ' [nobject="' + dotkey + '"]').parent().addClass('has-success') if $(this._element + ' [nobject="' + dotkey + '"]').parent('.checker').length
    this.save()

nobject.prototype.retrieve = (display,populate,poll) ->
  console.log('Nobject retrieving') if this._debug
  $.ajax
    type:'GET',
    url: if this._url? then this._url else this._api + '/' + (if typeof this._object is 'string' then this._object else this._object._id)
    cache:false
    processData:false
    contentType: 'application/json'
    dataType: 'json'
    success: (data) ->
      console.log('Nobject retrieved', data) if this._debug
      this._object = data if not this._object?
      this.display() if display
      this.populate() if populate
      this.poll() if poll
      if not _.isEqual(this._object,data)
        for k in this._keys
          if latest = dot(data,k) isnt current = dot(this._object,k) and current isnt dot(this._original,k) #this needs to know how to compare lists too
            # there is a conflict between what was received being different from what is current, and current does not match what it was at start
            return
          else
            # there is a difference but it does not clash with a local change, so just accept it anyway, and update the page
            # exit or suspend edit mode, inform the user, then rebuild the display
            this.update(k,latest)
    error: (data) ->
      console.log('Nobject retrieve error', data) if this._debug
      $('.nobjectMessage').html('<p>There is currently a problem communicating with the server. Editing is temporarily disabled. Please try again later by refreshing the page.</p>')
      this._editable = false
      setTimeout (() -> $('.nobjectMessage').html ''), 5000
    beforeSend: ((request) -> request.setRequestHeader "X-apikey", this._apikey) if this._apikey

nobject.prototype._pid
nobject.prototype.poll = () ->
  this._pid = setInterval this.retrieve, 3000

nobject.prototype.keys = (keys) ->
  console.log('Nobject setting/getting keys', keys) if this._debug
  this._keys = keys if keys?
  if not this._keys? and $(this._element + ' .nobject')?
    console.log('Nobject looking for keys in ' + this._element) if this._debug
    this._keys = []
    ths = this
    $(this._element + ' .nobject').each(() -> ths._keys.push($(this).attr('nobject')) if $(this).attr('nobject')?)
    # else should build a full key list out of the entire object?
    console.log('Nobject set keys', this._keys) if this._debug
  return this._keys

nobject.prototype.populate = (keys,val) ->
  console.log('Nobject populating', keys, val) if this._debug
  keys ?= this.keys()
  keys = [keys] if typeof keys is 'string'
  for k in keys
    val ?= dot this._object, k
    console.log('Nobject populating loop', k, val, typeof val) if this._debug
    # TODO has to depend on the type of value to be displayed, and into what type of element
    # and what if no vals? Does that mean it should be blank, or that it should not be changed from whatever it is???
    # what about mandatory vals?
    if val?
      if $(this._element + ' [nobject="' + k + '"]').is('select')
        $(this._element + ' [nobject="' + k + '"]').val(val)
      else if $(this._element + ' [nobject="' + k + '"]').is(':checkbox') and val
        $(this._element + ' [nobject="' + k + '"]').attr('checked','checked')
      else if val and $(this._element + ' [nobject="' + k + '"][value="' + val + '"]').length and $(this._element + ' [nobject="' + k + '"][value="' + val + '"]').is(':radio')
        $(this._element + ' [nobject="' + k + '"][value="' + val + '"]').attr('selected','selected')
      else
        $(this._element + ' [nobject="' + k + '"]').html(val).val(val)
    val = undefined # just a handy way to pass in one val to populate then throw it away after the first loop

nobject.prototype.display = (obj,keys,element) ->
  console.log('Nobject building display') if this._debug
  this._object = obj if obj?
  this._keys = keys if keys?
  this._element = element if element?
  if $(this._element + ' .nobject').length is 0
    display = '<div class="nobjectMessage" style="margin-top:5px;"></div>'
    for k in this.keys()
      val = dot this._object, k
      val = '' if not val?
      display += '<p><textarea class="nobject form-control" nobject="' + k + '" placeholder="' + k.replace('profile','').replace('service','').split('.').pop() + '">' + val + '</textarea></p>'
      # TODO need to know how to display different kinds of value - checkbox, radio. And for data types, lists, bools
      # and a way to add things like suggestion dropdowns and calendar displays on certain fields
    $(this._element).html display
    if not this._auto
      $(this._element).append('<p><a class="nobjectSave btn btn-primary" href="#">Save changes</a></p>')

nobject.prototype._changing
nobject.prototype.watch = () ->
  console.log('Nobject setting watchers') if this._debug
  ts = this
  change = () ->
    if not ts._changing
      ts._changing = true
      ths = $(this)
      setTimeout (() ->
        val # what other ways could the value be represented, and how to handle lists
        if ths.is(':checkbox')
          val = ths.is(':checked')
        else if ths.is(':radio')
          val = ths.val() if not val?
          if ths.is(':checked') and not val?
            val = [val] if typeof val is 'string'
            val.push ths.val()
          else
            val = ths.val()
        else
          val = ths.val()
        ts.update ths.attr('nobject'), val, false
        ts._changing = false
      ), 900
  $(this._element).on 'change', '.nobject', change
  $(this._element).on 'click', '.nobjectEdit', (() -> $(this._element).show()) # is this going to be necessary?
  $(this._element).on 'click', '.nobjectSave', (() -> ts.save())

nobject.prototype.validate = () ->
  console.log('Nobject validating') if this._debug
  return true
  # validate the input against some function or defaults, to see if save should progress

nobject.prototype._saving
nobject.prototype.save = (content,url,apikey) ->
  console.log('Nobject saving (if timeout permits)') if this._debug
  try content.preventDefault()
  if not this._saving
    this._saving = true
    ths = this
    setTimeout (() ->
      if typeof ths?.validate isnt 'function' or ths.validate()
        clearTimeout ths._pid if ths._pid?
        chng = JSON.parse(JSON.stringify(ths._changes)) if ths._changes isnt false
        ths._changes = {} if ths._changes isnt false
        $.ajax
          type: (if ths._overwrite is 'PUT' then 'PUT' else 'POST'),
          url: url ?= ths?._api + '/' + ths._object._id
          cache:false
          processData:false
          contentType: 'application/json'
          dataType: 'json'
          data: JSON.stringify content ?= (if ths._changes isnt false then chng else ths._object)
          success: (data) ->
            console.log('Nobject saved', data) if this._debug
            $(ths._element + ' .has-success').removeClass('has-success')
            ths._saving = false
            ths.poll() if ths?._poll
            # if backend accepts, leave edit mode, confirm to user
            ths?.success(data) if typeof ths.success is 'function' # is this known here, or does it have to be passed in?
            ths?.after(data) if typeof ths.after is 'function'
          error: (data) ->
            console.log('Nobject save error', data) if this._debug
            $(ths._element + ' .has-success').removeClass('has-success').addClass('has-error')
            ths._saving = false
            ths.poll() if ths?._poll
            # inform the user of a problem saving changes to the backend, and leave edit mode
            ths.error(data) if typeof ths?.error is 'function' # run any error function, if defined
          beforeSend: ((request) -> request.setRequestHeader "X-apikey", apikey) if apikey ?= ths?._apikey
    ), 900

nobject.prototype.sucess = (data) ->
  # what to do on save success
  return

nobject.prototype.error = (data) ->
  return
  # what to do on save error

nobject.prototype.after = () ->
  return
  # what to do after save - probably something to leave for the user to overwrite

