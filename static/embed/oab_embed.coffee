
@_L =
  api: 'https://api.lvatn.com'
_L.d = document
_L.gebi = (id) -> return document.getElementById id.replace('#','')
_L.gebc = (cls) -> return document.getElementsByClassName cls.replace('.','')
_L.gebn = (n) -> 
  r = document.getElementsByTagName n.replace('<','').replace('>','') # e.g. by the element name, like "div"
  return if r? then r else  document.getElementsByName n # otherwise by the "name" attribute matching n
_L.each = (elems, key, val) ->
  if typeof elems is 'string'
    if elems.startsWith '#'
      elems = [_L.gebi elems]
    else if elems.startsWith '.'
      elems = _L.gebc elems
    else
      elems = _L.gebn elems
  else if typeof elems is 'object'
    elems = [elems] if not Array.isArray elems
  if elems?
    for elem in elems
      if elem?
        if typeof key is 'function' then key(elem) else _L.set elem key, val
_L.listen = (action, els, fn) ->
  _L.each els, (el) -> 
    if action is 'enter'
      action = 'keyup'
      wfn = (e) -> fn(e) if e.keyCode is 13
    else
      wfn = fn
    #el = _L.clone el # gets rid of all listeners so we don't end up with dups - but note, gets rid of ALL. TODO use a wrapper to manage these independently
    if not _L.has el, 'listen_'+action
      _L.class el, 'listen_'+action
      el.addEventListener action, (e) -> wfn(e)
_L.show = (els, html, append) ->
  _L.each els, (el) -> 
    if typeof html is 'string'
      el.innerHTML = (if append then el.innerHTML else '') + html
    was = _L.get el, '_L_display'
    was = 'block' if typeof was isnt 'string' or was is 'none' # TODO should be inline in which cases...
    el.style.display = was
_L.hide = (els) ->
  _L.each els, (el) -> 
    if el.style.display isnt 'none'
      _L.set el, '_L_display', el.style.display
    el.style.display = 'none'
_L.get = (els, attr) ->
  res = undefined
  _L.each els, (el) ->
    if not attr?
      try res = el.value
      res = undefined if typeof res is 'string' and not res.length
    try res ?= el.getAttribute attr
  return res
_L.set = (els, attr, val) ->
  _L.each els, (el) ->
    # TODO handle dot notation keys e.g if attr is style.display
    if not val? or attr is 'value' or attr is 'val'
      try el.value = if not val? then attr else val
    else
      try el.setAttribute attr, val
_L.checked = (els) ->
  res = true
  _L.each els, (el) -> res = el.checked
  return res
_L.html = (els, html, append, show) ->
  rs = []
  _L.each els, (el) -> 
    if html
      el.innerHTML = (if append then el.innerHTML else '') + html
    rs.push el.innerHTML
    _L.show(el) if show
  return if rs.length is 1 then (rs[0] ? '') else if rs.length then rs else ''
_L.append = (els, html) -> _L.html els, html, true
_L.remove = (els) -> _L.each els, (el) -> el.parentNode.removeChild el
_L.class = (el, cls) -> 
  rs = []
  classes = el.getAttribute 'class'
  classes ?= ''
  if typeof cls is 'string'
    if classes.indexOf(cls) is -1
      classes += ' ' if classes.length
      classes += cls
    else
      classes = classes.replace(cls,'').trim().replace(/  /g,' ')
    el.setAttribute 'class', classes
  for c in classes.split ' '
    rs.push(c) if c not in rs
  return rs
_L.classes = (els) -> return _L.class els
_L.has = (el, cls) ->
  classes = _L.classes el
  cls = cls.replace('.') if cls.startsWith '.'
  if cls in classes
    return true
  else
    return if el.getAttribute(cls) then true else false
_L.css = (els, key, val) ->
  rs = []
  _L.each els, (el) ->
    s = _L.get el, 'style'
    s ?= ''
    style = {}
    for p in s.split ';'
      ps = p.split ':'
      style[ps[0].trim()] = ps[1].trim() if ps.length is 2
    if not key? or style[key]?
      rs.push if key? then style[key] else style
    style[key] = val if val?
    ss = ''
    for k of style
      ss += ';' if ss isnt ''
      ss += k + ':' + style[k]
    _L.set el, 'style', ss
  if not val?
    return if rs.length is 1 then rs[0] else rs
_L.clone = (el, children) ->
  if children
    n = el.cloneNode true
  else
    n = el.cloneNode false
    n.appendChild(el.firstChild) while el.hasChildNodes()
  el.parentNode.replaceChild n, el
  return n
    
_L.jx = (route, q, success, error, api, method, data, headers) ->
  # add auth options to this
  api ?= _L.api
  if route.startsWith 'http'
    url = route
  else
    url = api + if api.endsWith('/') then '' else '/'
    url += (if route.startsWith('/') then route.replace('/','') else route) if route
  if typeof q is 'string'
    url += (if url.indexOf('?') is -1 then '?' else '&') + (if q.indexOf('=') is -1 then 'q=' else '') + q
  else if typeof q is 'object'
    url += '?' if url.indexOf('?') is -1
    url += p + '=' + q[p] + '&' for p of q
  xhr = new XMLHttpRequest()
  xhr.open (method ? 'GET'), url
  xhr.setRequestHeader(h, headers[h]) for h of headers ? {}
  xhr.send data
  xhr.onload = () ->
    if xhr.status isnt 200
      try error xhr
    else
      try
        success JSON.parse(xhr.response), xhr
      catch err
        console.log err
        try
          success xhr
        catch
          try error xhr
    _L.loaded(xhr) if typeof _L.loaded is 'function'
  xhr.onerror = (err) -> try error(err)

_L.post = (route, data, success, error, api, headers) ->
  headers ?= {}
  if typeof data is 'object'
    if typeof data.append isnt 'function' # a FormData object will have an append function, a normal json object will not. FormData should be POSTable by xhr as-is
      data = JSON.stringify data
      headers['Content-type'] ?= 'application/json'
  route += (if route.indexOf('?') is -1 then '?' else '&') + '_=' + Date.now() # set a random header to try to break any possible caching
  _L.jx route, undefined, success, error, api, 'POST', data, headers
  
_L.dot = (obj, key, value, del) ->
  if typeof key is 'string'
    return API.collection.dot obj, key.split('.'), value, del
  else if key.length is 1 and (value? or del?)
    if del is true or value is '$DELETE'
      if obj instanceof Array
        obj.splice key[0], 1
      else
        delete obj[key[0]]
      return true
    else
      obj[key[0]] = value
      return true
  else if key.length is 0
    return obj
  else
    if not obj[key[0]]?
      if value?
        obj[key[0]] = if isNaN(parseInt(key[0])) then {} else []
        return _L.dot obj[key[0]], key.slice(1), value, del
      else
        return undefined
    else
      return _L.dot obj[key[0]], key.slice(1), value, del



_oab = (opts) ->
  opts ?= {}
  # other useful values to pass in: openurl or ill will disable those features for instantill if set to false
  this[o] = opts[o] for o of opts
  this.uid ?= 'anonymous'
  this.api ?= if window.location.host.indexOf('dev.openaccessbutton.org') isnt -1 then 'https://dev.api.cottagelabs.com/service/oab' else 'https://api.openaccessbutton.org'
  this.plugin ?= 'instantill' # has to be defined at startup, as either instantill or shareyourpaper
  this.element ?= '#' + this.plugin
  this.pushstate ?= true # if true, the embed will try to add page state changes to the browser state manager
  this.config ?= {}
  this.data ?= {} # the data obj to send to backend
  this.f ?= {} # the result of the find/ill/permission request to the backend
  this.template ?= _oab[this.plugin + '_template'] # template or css can be passed in or are as defined below
  this.css ?= _oab.css
  this.bootstrap ?= true # if true then bootstrap classes will be added to buttons and form elements

  this._loading = false # tracks when loads are occurring
  this.submit_after_metadata = false # used by instantill to track if metadata has been provided by user
  this.file = false # used by syp to store the file for sending to backend

  _L.loaded = this.loaded if this.loaded? # if this is set to a function, it will be passed to _leviathan loaded, which gets run after every ajax call completes

  _L.append('body', '<div id="' + this.element + '"></div>') if not _L.gebi this.element
  _L.html this.element, ''

  if window.location.search.indexOf('local=') isnt -1
    this.local = false
  if window.location.search.indexOf('config=') isnt -1
    try this.config = JSON.parse window.location.search.split('config=')[1].split('&')[0].split('#')[0]
  if window.location.search.indexOf('config.') isnt -1
    configs = window.location.search.split 'config.'
    configs.shift()
    for c in configs
      cs = c.split '='
      if cs.length is 2
        csk = cs[0].trim()
        csv = cs[1].split('&')[0].split('#')[0].trim()
        this.configure csk, csv, false

  this.configure()

  if not this.config.autorun # stupidly, true means don't run it...
    ap = this.config.autorunparams ? ['doi','title','url','atitle','rft_id','journal','issn','year','author']
    ap.push('confirmed') if 'confirmed' not in ap # confirmed here is extra to the ill ones, used to confirm the file has been confirmed
    ap = ap.replace(/"/g,'').replace(/'/g,'').split(',') if typeof ap is 'string'
    for o in ap
      o = o.split('=')[0].trim()
      eq = o.split('=')[1].trim() if o.indexOf('=') isnt -1
      this.data[eq ? o] = decodeURIComponent(window.location.search.replace('?','&').split('&'+o+'=')[1].split('&')[0].replace(/\+/g,' ')) if (window.location.search.replace('?','&').indexOf('&'+o+'=') isnt -1)
  if window.location.search.indexOf('email=') isnt -1
    this.data.email = window.location.search.split('email=')[1].split('&')[0].split('#')[0]
    _L.remove '#_oab_collect_email'
  if window.location.search.indexOf('panel=') isnt -1
    this.panel window.location.search.split('panel=')[1].split('&')[0].split('#')[0]
  if window.location.search.indexOf('section=') isnt -1
    this.section window.location.search.split('section=')[1].split('&')[0].split('#')[0]
  this.find() if this.data.doi or (this.plugin is 'instantill' and (this.data.title or this.data.url))
  window.addEventListener "popstate", (pe) => this.state(pe)
  return this



_oab.prototype.cml = () -> return this.config.problem_email ? this.config.email ? this.config.adminemail ? ''
_oab.prototype.contact = () -> return 'Please try ' + (if this.cml() then '<a href="mailto:' + this.cml() + '">contacting your library</a>' else 'contacting your library') + ' directly'

_oab.prototype.loading = (load) ->
  _L.hide '#_oab_error'
  if load isnt true and (this._loading or load is false)
    try clearInterval this._loading
    this._loading = false
    _L.each '._oab_loading', (el) => 
      if _L.has el, '_oab_continue'
        el.innerHTML = 'Continue'
      else if _L.has el, '_oab_submit'
        el.innerHTML = 'Complete request'
      else if _L.has el, '_oab_deposit'
        el.innerHTML = 'Deposit'
      else if _L.has el, '_oab_find'
        el.innerHTML = 'Next'
      else
        el.innerHTML = 'Find ' + if this.config.saypaper then 'paper' else 'article' # this would only happen on instantill, as "Next" above is the default for syp
  else
    _L.html '._oab_find', 'Searching .'
    _L.html '._oab_submit', 'Submitting .'
    _L.html '._oab_deposit', 'Depositing .'
    this._loading = setInterval (() ->
      for button in _L.gebc '._oab_loading'
        dots = button.innerHTML.split '.'
        if dots.length >= 4
          button.innerHTML = dots[0]
        else
          button.innerHTML = button.innerHTML + ' .'
      ), 700

_oab.prototype.state = (pop) ->
  if this.pushstate
    try
      u = window.location.pathname
      if not pop?
        if window.location.href.indexOf('shareyourpaper.org') isnt -1 and this.data.doi?
          u = window.location.pathname.split('/10.')[0] + '/' + this.data.doi + window.location.search + window.location.hash
        else if window.location.href.indexOf('/setup') is -1 and window.location.href.indexOf('/demo') is -1
          if this.data.doi? or this.data.title? or this.data.url?
            k = if this.data.doi then 'doi' else if this.data.title then 'title' else 'url'
            u += window.location.search.split('?' + k + '=')[0].split('&' + k + '=')[0]
            u += if u.indexOf('?') is -1 then '?' else '&'
            u += k + '=' + this.data[k] + window.location.hash
      window.history.pushState "", (if pop? then "search" else "find"), u
      if pop?
        # what to do with the pop event? for now just triggers a restart if user tries to go back
        this.restart()

_oab.prototype.restart = (e, val) ->
  try e.preventDefault()
  this.data = {}
  this.f = {}
  this.loading false
  this.file = false
  _L.hide '._oab_panel'
  _L.show '#_oab_inputs'
  this.configure()
  if val
    _L.set '#_oab_input', val
    this.find()
  else
    _L.set '#_oab_input', ''
    
_oab.prototype.demo = (e, val, panel, section) ->
  try e.preventDefault()
  # useful for demo/test, just does a restart but uses the config demo val if one is present
  if val
    if val is 'deposit'
      # trigger a fake deposit for syp demo
      this.f = {metadata: {title: 'example', journal: 'example', doi: '10.1234/oab-syp-version'}}
      this.deposit()
    else
      val = this.config.val if typeof val isnt 'string' or (this.plugin is 'instantill' and typeof this.config.val is 'string')
      this.restart undefined, val
  this.panel(panel) if panel?
  this.section(section) if section?

_oab.prototype.ping = (what) ->
  try
    if what.indexOf(this.plugin) is -1
      what = '_' + what if not what.startsWith '_'
      what = this.plugin + what
    url = if this.api.indexOf('dev.') isnt -1 then 'https://dev.api.cottagelabs.com' else 'https://api.cottagelabs.com'
    url += '/ping.png?service=openaccessbutton&action=' + what + '&from=' + this.uid
    url += '&pilot=' + this.config.pilot if this.config.pilot
    url += '&live=' + this.config.live if this.config.live
    _L.jx url

_oab.prototype.panel = (panel, section) ->
  if he = _L.gebi '_oab_' + (if panel.startsWith('_oab_') then panel.replace('_oab_') else panel)
    _L.hide '._oab_panel'
    _L.show he
    this.section(section) if section

_oab.prototype.section = (section) ->
  # useful for demo/test, just shows a specific section within a panel
  fe = _L.gebi '_oab_' + (if section.startsWith('_oab_') then section.replace('_oab_','') else section)
  fe = _L.gebc '_oab_' + (if section.startsWith('_oab_') then section.replace('_oab_','') else section) if not fe
  if fe
    _L.hide '._oab_section'
    _L.show fe

_oab.prototype.submit = (e) -> # only used by instantill
  try e.preventDefault()
  if not this.f?.ill?.openurl and not this.data.email and _L.gebi '#_oab_email'
    this.validate()
  else if JSON.stringify(this.f) is '{}' or (not this.f.metadata?.title or not this.f.metadata?.journal or not this.f.metadata?.year)
    if this.submit_after_metadata
      this.done false
    else
      this.submit_after_metadata = true
      this.metadata()
  else
    this.loading()
    data = {match: this.f.input, email:this.data.email, from: this.uid, plugin: this.plugin, embedded: window.location.href}
    data.config = this.config
    data.metadata = this.f.metadata ? {}
    for k in ['title','journal','year','doi']
      data.metadata[k] = this.data[k] if not data.metadata[k] and this.data[k]
      if data.metadata.doi and data.metadata.doi.indexOf('http') is 0
        data.metadata.url = data.metadata.doi
        delete data.metadata.doi
    nfield = if this.config.notes then this.config.notes else 'notes'
    data[nfield] = 'The user provided some metadata. ' if this.data.usermetadata
    data.pilot = this.config.pilot if this.config.pilot
    data.live = this.config.live if this.config.live
    if this.f?.ill?.subscription or this.f?.availability
      if typeof data[nfield] isnt 'string' then data[nfield] = '' else data[nfield] += ' '
      if this.f.ill?.subscription
        data[nfield] += 'Subscription check done, found ' + (this.f.ill.subscription.url ? (if this.f.ill.subscription.journal then 'journal' else 'nothing')) + '. '
      if this.f.metadata?
        data[nfield] += 'OA availability check done, found ' + (this.f.url ? 'nothing') + '. '
    if this.f?.ill?.openurl and this.openurl isnt false and not data.email
      data.forwarded = true
    if this.openurl is 'demo'
      console.log 'Not POSTing ILL and not forwarding to ' + this.f.ill.openurl + ' for demo purposes'
      console.log data
    else
      _L.post(
        this.api+'/ill'
        data
        (res) => this.done res
        () => this.done false
      )

_oab.prototype.validate = () ->
  if this.f.ill?.terms and not _L.checked '#_oab_read_terms'
    _L.show '#_oab_error', '<p>Please agree to the terms first.</p>'
  else
    email = (_L.get('#_oab_email') ? '').trim()
    if not email.length
      _L.show '#_oab_error', '<p>Please provide your university email address.</p>'
      _L.css '#_oab_email', 'border-color', '#f04717'
      _L.gebi('#_oab_email').focus()
    else
      this.loading()
      _L.post(
        this.api + '/validate?uid=' + this.uid + '&email=' + email
        this.config
        (res) =>
          this.loading false
          if res is true
            this.data.email = _L.get('#_oab_email').trim()
            if this.plugin is 'instantill' then this.submit() else this.deposit()
          else if res is 'baddomain'
            _L.show '#_oab_error', '<p>Please try again with your university email address.</p>'
          else
            _L.show '#_oab_error', '<p>Sorry, your email does not look right. ' + (if res isnt false then 'Did you mean ' + res + '? ' else '') + 'Please check and try again.</p>'
        () => 
          this.data.email = _L.get('#_oab_email').trim()
          if this.plugin is 'instantill' then this.submit() else this.deposit()
      )

_oab.prototype.metadata = (submitafter) -> # only used by instantill
  for m in ['title','year','journal','doi']
    if this.f?.metadata?[m]? or this.data[m]?
      _L.set '#_oab_'+m, (this.f.metadata ? this.data)[m].split('(')[0].trim()
  #if this.f?.doi_not_in_crossref
  #  _L.html '#_oab_bad_doi', this.f.doi_not_in_crossref
  #  _L.show '#_oab_doi_not_in_crossref'
  _L.hide '._oab_panel'
  _L.show '#_oab_metadata'

_oab.prototype.openurl = () -> # only used by instantill
  _L.post(
    this.api+'/ill/openurl?' + (if this.uid then 'uid='+this.uid+'&' else '') + (if this.data.usermetadata then 'usermetadata=true&' else '')
    (if this.uid then this.f.metadata else {metadata: this.f.metadata, config: this.config})
    (res) => window.location = res
    (data) =>
      try
        window.location = data
      catch err
        this.done undefined, 'instantill_openurl_couldnt_create_ill'
  )

_oab.prototype.done = (res, msg) ->
  this.loading false
  if this.f.ill?.openurl and this.openurl isnt false
    if this.submit_after_metadata
      this.openurl()
    else
      window.location = this.f.ill.openurl
  else
    _L.hide '._oab_panel'
    _L.hide '._oab_done'
    if typeof res is 'string' and _L.gebi '_oab_' + res
      _L.show '#_oab_' + res # various done states for shareyourpaper
      _L.hide('#_oab_done_restart') if res is 'confirm'
    else if res
      _L.html '#_oab_done_header', '<h3>Thanks! Your request has been received</h3><p>Your confirmation code is: ' + res + ', this will not be emailed to you. The ' + (if this.config.saypaper then 'paper' else 'article') + ' will be sent to ' + this.data.email + ' as soon as possible.</p>'
    else # only instantill falls through to here
      _L.html '#_oab_done_header', '<h3>Sorry, we were not able to create an Interlibrary Loan request for you.</h3><p>' + this.contact() + '</p>'
      _L.html '#_oab_done_restart', 'Try again'
      this.ping msg ? 'instantill_couldnt_submit_ill'
      setTimeout this.restart, 6000
    _L.show '#_oab_done'
  this.after() if typeof this.after is 'function'

_oab.prototype.deposit = (e) -> # only used by shareyourpaper
  try e.preventDefault()
  if not this.data.email and _L.gebi '#_oab_email'
    this.validate()
  else if fl = _L.gebi '_oab_file'
    if fl.files? and fl.files.length
      this.file = new FormData()
      this.file.append 'file', fl.files[0]
    else if not this.f?.url? and not this.f?.permissions?.permissions?.archiving_allowed and not this.config.dark_deposit_off
      _L.show '#_oab_error', '<p>Whoops, you need to give us a file! Check it\'s uploaded.</p>'
      _L.css fl, 'border-color','#f04717'
      return
  
    this.loading()
    # this could be just an email for a dark deposit, or a file for actual deposit
    # if the file is acceptable and can go in zenodo then we don't bother getting the email address
    data = {from: this.uid, plugin: this.plugin, embedded:window.location.href, metadata: this.f?.metadata }
    data.config = this.config
    data.email = this.data.email if this.data.email
    data.confirmed = this.data.confirmed if this.data.confirmed
    data.redeposit = this.f.url if typeof this.f?.url is 'string'
    data.pilot = this.config.pilot if this.config.pilot
    data.live = this.config.live if this.config.live
    if this.file
      for d of data
        if d is 'metadata'
          for md of data[d]
            this.file.append(md,data[d][md]) if (typeof data[d][md] is 'string' or typeof data[d][md] is 'number')
        else
          this.file.append d,data[d]
      data = this.file

    _L.post(
      this.api+'/deposit', # + (this.f.catalogue ? '')
      data
      (res) =>
        this.loading false
        if this.file
          if res.zenodo?.already or (this.data.confirmed and not res.zenodo?.url) #or not this.f?.permissions?.file?.archivable
            this.done 'check'
          else if res.error
            # if we should be able to deposit but can't, we stick to the positive response and the file will be manually checked
            this.done 'partial'
          else if res.zenodo?.url
            # deposit was possible, show the user a congrats page with a link to the item in zenodo
            _L.set '#_oab_zenodo_url', res.zenodo.url
            if res.embargo
              info = '<p>You\’ve done your part for now. Unfortunately, ' + jn + ' won’t let us make it public until '
              info += if res.embargo_UI then res.embargo_UI else res.embargo
              info += '. After release, you\’ll find your paper on ' + (this.config.repo_name ? 'ScholarWorks') + ', Google Scholar, Web of Science.</p>'
              info += '<h3>Your paper will be freely available at this link:</h3>'
            else
              info = '<p>You\’ll soon find your paper freely available in ' + (this.config.repo_name ? 'ScholarWorks') + ', Google Scholar, Web of Science, and other popular tools.'
              info += '<h3>Your paper is now freely available at this link:</h3>'
            _L.html '#_oab_zenodo_embargo', info
            this.done 'zenodo'
          else
            # if the file given is not a version that is allowed, show a page saying something looks wrong
            # also the backend should create a dark deposit in this case, but delay it by six hours, and cancel if received in the meantime
            this.done 'confirm'
        else if res.type is 'redeposit'
          this.done 'redeposit'
        else
          this.done 'success'
      () =>
        this.loading false
        _L.show '#_oab_error', '<p>Sorry, we were not able to deposit this paper for you. ' + this.contact() + '</p><p><a href="#" class="_oab_restart">Try again</a></p>'
        this.ping('shareyourpaper_couldnt_submit_deposit')
    )

_oab.prototype.permissions = (data) -> # only used by shareyourpaper
  this.f = data if data?
  this.loading false
  if this.f?.doi_not_in_crossref
    this.f = {}
    _L.show '#_oab_error', '<p>Double check your DOI, that doesn\'t look right to us.</p>'
    _L.gebi('_oab_input').focus()
  else if this.f?.metadata?.crossref_type? and this.f.metadata.crossref_type not in ['journal-article', 'proceedings-article']
    _L.gebi('_oab_input').focus()
    nj = '<p>Sorry, right now this only works with academic journal articles.'
    if this.cml()
      nj += ' To get help with depositing, <a href="'
      nj += if this.config.old_way then (if this.config.old_way.indexOf('@') isnt -1 then 'mailto:' else '') + this.config.old_way else 'mailto:' + this.cml()
      nj += "?subject=Help%20depositing%20&body=Hi%2C%0D%0A%0D%0AI'd%20like%20to%20deposit%3A%0D%0A%0D%0A%3C%3CPlease%20insert%20a%20full%20citation%3E%3E%0D%0A%0D%0ACan%20you%20please%20assist%20me%3F%0D%0A%0D%0AYours%20sincerely%2C" + '">click here</a>'
    _L.show '#_oab_error', nj + '.</p>'
  else if not this.f?.metadata?.title?
    _L.show '#_oab_error', '<h3>Unknown paper</h3><p>Sorry, we cannot find this paper or sufficient metadata. ' + this.contact() + '</p>'
    this.ping 'shareyourpaper_unknown_article'
  else
    _L.hide '._oab_panel'
    _L.hide '._oab_section'
    _L.show '#_oab_permissions'
    this.loading false
    tcs = 'terms <a href="https://openaccessbutton.org/terms" target="_blank">[1]</a>'
    tcs += ' <a href="' + this.config.deposit_terms + '" target="_blank">[2]</a>' if this.config.deposit_terms
    ph = 'your.name@institution.edu';
    if this.config.email_domains? and this.config.email_domains.length
      this.config.email_domains = this.config.email_domains.split(',') if typeof this.config.email_domains is 'string'
      ph = this.config.email_domains[0]
      ph = ph.split('@')[1] if ph.indexOf('@') isnt -1
      ph = ph.split('//')[1] if ph.indexOf('//') isnt -1
      ph = ph.toLowerCase().replace('www.','')
    ph = 'your.name@institution.edu' if not ph? or ph.length < 3
    ph = 'your.name@' + ph if ph.indexOf('@') is -1
    if this.data.email
      _L.hide '._oab_get_email'
    else
      _L.show '._oab_get_email'
      _L.set '#_oab_email', 'placeholder', ph
      _L.html '._oab_terms', tcs
    refs = ''
    for p of this.f?.permissions?.permissions?.policy_full_text ? []
      refs += ' <a target="_blank" href="' + this.f.permissions.permissions.policy_full_text[p] + '">[' + (parseInt(p)+1) + ']</a>'
    _L.html '._oab_refs', refs
    paper = if this.f?.metadata?.doi then '<a target="_blank" href="https://doi.org/' + this.f.metadata.doi + '"><u>your paper</u></a>' else 'your paper'
    _L.html '._oab_your_paper', (if this.f?.permissions?.permissions?.version_allowed is 'publisher pdf' then 'the publisher pdf of ' else '') + paper
    _L.html '._oab_journal', this.f?.metadata?.journal_short ? 'the journal'
    # set config by this.config.repo_name put name in ._oab_repo

    if this.f.url
      # it is already OA, depending on settings can deposit another copy
      _L.set '._oab_oa_url', 'href', this.f.url
      if this.config.allow_oa_deposit # when true, they can't...
        _L.hide '._oab_get_email'
        _L.show '._oab_oa'
      else
        _L.show '._oab_oa_deposit'
    else if this.f?.permissions?.permissions?.archiving_allowed or this.config.dark_deposit_off
      if this.config.dark_deposit_off or this.f.permissions?.ricks?.application?.can_archive_conditions?.permission_required
        # permission must be requested first
        rm = 'mailto:' + (this.f.permissions?.ricks?.application?.can_archive_conditions?.permission_required_contact ? this.config.deposit_help ? this.cml()) + '?'
        rm += 'cc=' + (this.config.deposit_help ? this.cml()) + '&' if this.f.permissions?.ricks?.application?.can_archive_conditions?.permission_required_contact
        rm += 'subject=Request%20to%20self%20archive%20' + (this.f.metadata?.doi ? '') + '&body=';
        rm += encodeURIComponent 'To whom it may concern,\n\n'
        rm += encodeURIComponent 'I am writing to request permission to deposit the full text of my paper "' + (this.f.metadata?.title ? this.f.metadata?.doi ? 'Untitled paper') + '" '
        rm += encodeURIComponent 'published in "' + this.f.metadata.journal + '"' if this.f.metadata?.journal
        rm += encodeURIComponent '\n\nI would like to archive the final pdf. If that is not possible, I would like to archive the accepted manuscript. Ideally, I would like to do so immediately but will respect a reasonable embargo if requested.\n\n'
        if this.config.repo_name
          rm += encodeURIComponent 'I plan to deposit it into "' + this.config.repo_name + '", a not-for-profit, digital, publicly accessible repository for scholarly work created for researchers ' + (if this.config.institution_name then 'at ' + this.config.institution_name else '') + '. It helps make research available to a wider audience, get citations for the original article, and assure its long-term preservation. The deposit will include a complete citation of the published version, and a link to it.\n\n'
        rm += encodeURIComponent 'Thank you for your attention and I look forward to hearing from you.'
        _L.set '#_oab_reviewemail', 'href', rm
        # or to confirm permission has been received
        pm = 'mailto:' + (this.config.deposit_help ? this.cml()) + '?subject=Permission%20Given%20to%20Deposit%20' + (this.f.metadata?.doi ? '') + '&body='
        pm += encodeURIComponent 'To whom it may concern,\n\nAttached is written confirmation of permission I\'ve been given to deposit, and the permitted version of my paper: '
        pm += encodeURIComponent '"' + (this.f.metadata?.title ? this.f.metadata?.doi ? 'Untitled paper') + '" \n\nCan you please deposit it into the repository on my behalf? \n\nSincerely, '
        _L.set '#_oab_permissionemail', 'href', pm
        _L.hide '._oab_get_email'
        _L.show '._oab_permission_required'
      else
        # can be shared, depending on permissions info
        _L.hide('#_oab_not_pdf') if this.f?.permissions?.permissions?.version_allowed is 'publisher pdf'
        if typeof this.f?.permissions?.permissions?.licence_required is 'string' and this.f.permissions.permissions.licence_required.indexOf('other-') is 0
          _L.html '#_oab_licence', 'under the publisher\'s terms.' + refs
        else
          _L.html '#_oab_licence', this.f?.permissions?.permissions?.licence_required ? 'CC-BY'
        _L.show '._oab_archivable'
    else
      # can't be directly shared but can be passed to library for dark deposit
      _L.hide '#_oab_file'
      _L.show '._oab_dark_deposit'

_oab.prototype.findings = (data) -> # only used by instantill
  this.f = data if data?
  if ct = this.f.metadata?.crossref_type
    if ct not in ['journal-article','proceedings-article','posted-content']
      if ct in ['book-section','book-part','book-chapter']
        err = '<p>Please make your request through our ' + (if this.config.book then '<a href="' + this.config.book + '">book form</a>' else 'book form')
      else
        err = '<p>We can only process academic journal articles, please use another form.'
      _L.show '#_oab_error', err + '</p>'
      return

  _L.hide '._oab_panel'
  _L.hide '._oab_section'
  this.loading false

  if this.config.resolver
    # new setting to act as a link resolver, try to pass through immediately if sub url, OA url, or lib openurl are available
    # TODO confirm if this should send an ILL to the backend first, as a record, or maybe just a pinger
    # also check if could forward the user to the new page before the send to backend succeeds / errors
    data = {match: this.f.input, from: this.uid, plugin: this.plugin, embedded: window.location.href}
    data.config = this.config
    data.metadata = this.f.metadata ? {}
    data.pilot = this.config.pilot if this.config.pilot
    data.live = this.config.live if this.config.live
    if this.f.ill?.subscription?.url
      data.resolved = 'subscription'
      _L.post(this.api+'/ill', data, (() => window.location = this.f.ill.subscription.url), (() => window.location = this.f.ill.subscription.url))
    else if this.f.url
      data.resolved = 'open'
      _L.post(this.api+'/ill', data, (() => window.location = this.f.url), (() => window.location = this.f.url))
    else if this.f.ill?.openurl
      data.resolved = 'library'
      _L.post(this.api+'/ill', data, (() => window.location = this.f.ill.openurl), (() => window.location = this.f.ill.openurl))

  _L.show '#_oab_findings'
  if this.f.ill?.error
    _L.show '#_oab_error', '<p>Please note, we encountered errors querying the following subscription services: ' + this.f.ill.error.join(', ') + '</p>'
  if this.f.metadata?.title? or this.f.ill?.subscription?.demo
    citation = '<h2>' + (if this.f.ill?.subscription?.demo then '<Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL' else this.f.metadata.title) + '</h2>'
    if this.f.metadata.year or this.f.metadata.journal or this.f.metadata.volume or this.f.metadata.issue
      citation += '<p><b style="color:#666;">'
      citation += (this.f.metadata.year ? '') + (if this.f.metadata.journal or this.f.metadata.volume or this.f.metadata.issue then ', ' else '') if this.f.metadata.year
      if this.f.metadata.journal
        citation += this.f.metadata.journal
      else
        citation += 'vol. ' + this.f.metadata.volume if this.f.metadata.volume
        citation += (if this.f.metadata.volume then ', ' else '') + 'issue ' + this.f.metadata.issue if this.f.metadata.issue
      citation += '</b></p>'
    _L.html '#_oab_citation', citation

    hassub = false
    hasoa = false
    if this.f.ill?.subscription?.journal or this.f.ill?.subscription?.url
      hassub = true
      # if sub url show the url link, else show the "should be able to access on pub site
      _L.set('#_oab_sub_url', 'href', this.f.ill.subscription.url) if this.f.ill.subscription.url?
      _L.show '#_oab_sub_available'
    else if this.f.url
      hasoa = true
      _L.set '#_oab_url', 'href', this.f.url
      _L.show '#_oab_oa_available'
    if this.f.ill and this.ill isnt false and not ((this.config.noillifsub and hassub) or (this.config.noillifoa and hasoa))
      _L.html '#_oab_cost_time', '<p>It ' + (if this.config.cost then 'costs ' + this.config.cost else 'is free to you,') + ' and we\'ll usually email the link within ' + (this.config.time ? '24 hours') + '.<br></p>'
      if not this.data.email
        if this.f.ill.openurl and this.openurl isnt false
          _L.hide '#_oab_collect_email'
        else
          if this.f.ill.terms
            _L.show '#_oab_terms_note'
            _L.set '#_oab_terms_link', 'href', this.f.ill.terms
          else
            _L.hide '#_oab_terms_note'
      _L.show '#_oab_ask_library'

  else if this.data.usermetadata
    _L.html '#_oab_citation', '<h3>Unknown ' + (if this.config.saypaper then 'paper' else 'article') + '</h3><p>Sorry, we can\'t find this ' + (if this.config.saypaper then 'paper' else 'article') + ' or sufficient metadata. ' + this.contact() + '</p>'
    this.ping 'shareyourpaper_unknown_article'
    setTimeout this.restart, 6000
  else
    this.metadata()

_oab.prototype.find = (e) ->
  try e.preventDefault()
  if JSON.stringify(this.f) isnt '{}'
    for k in ['title','journal','year','doi']
      if v = _L.get '#_oab_' + k
        if this.data[k] isnt v
          this.data[k] = v
          this.data.usermetadata = true
    if this.data.year and this.data.year.length isnt 4
      delete this.data.year
      _L.show '#_oab_error', '<p>Please provide the full year e.g 2019</p>'
      return
    if not this.data.title or not this.data.journal or not this.data.year
      _L.show '#_oab_error', '<p>Please complete all required fields</p>'
      return
    if this.submit_after_metadata
      this.submit()
      return
      
  this.data.title ?= this.data.atitle if this.data.atitle
  this.data.doi ?= this.data.rft_id if this.data.rft_id
  if this.data.doi and this.data.doi.indexOf('10.') isnt -1 and (this.data.doi.indexOf('/') is -1 or this.data.doi.indexOf('http') is 0)
    this.data.url = this.data.doi
    delete this.data.doi
  if val = _L.get('#_oab_input')
    val = val.trim().replace(/\.$/,'')
    if val.length
      if val.indexOf('doi.org/') isnt -1
        this.data.url = val
        this.data.doi = '10.' + val.split('10.')[1].split(' ')[0]
      else if val.indexOf('10.') isnt -1
        this.data.doi = '10.' + val.split('10.')[1].split(' ')[0]
      else if val.indexOf('http') is 0 or val.indexOf('www.') isnt -1
        this.data.url = val
      else if val.toLowerCase().replace('pmc','').replace('pmid','').replace(':','').replace(/[0-9]/g,'').length is 0
        this.data.id = val
      else
        this.data.title = val
  else if this.data.doi or this.data.title or this.data.url or this.data.id
    _L.set '#_oab_input', this.data.doi ? this.data.title ? this.data.url ? this.data.id

  if this.plugin is 'instantill' and not this.data.doi and this.data.title and this.data.title.length < 30 and this.data.title.split(' ').length < 3
    this.metadata() # need more metadata for short titles
  else if not this.data.doi and (this.plugin is 'shareyourpaper' or (not this.data.url and not this.data.pmid and not this.data.pmcid and not this.data.title and not this.data.id))
    if this.plugin is 'shareyourpaper'
      delete this.data.title
      delete this.data.url
      delete this.data.id
    _L.show '#_oab_error', '<p><span>&#10060;</span> Sorry please provide ' + if this.plugin is 'instantill' then 'the full DOI, title, citation, PMID or PMC ID.</p>' else 'a valid DOI.</p>'
  else
    this.state()
    this.loading()
    this.data.config = this.config
    this.data.from ?= this.uid
    this.data.plugin ?= this.plugin
    this.data.embedded ?= window.location.href
    this.data.pilot ?= this.config.pilot if this.config.pilot
    this.data.live ?= this.config.live if this.config.live
    _L.post(
      this.api+'/find'
      this.data
      (data) => if this.plugin is 'instantill' then this.findings(data) else this.permissions(data)
      () => _L.show '#_oab_error', '<p>Oh dear, the service is down! We\'re aware, and working to fix the problem. ' + this.contact() + '</p>'
    )

_oab.css = '
<style>
._oab_form {
  display: inline-block;
  width: 100%;
  height: 34px;
  padding: 6px 12px;
  font-size: 1em;
  line-height: 1.428571429;
  color: #555555;
  vertical-align: middle;
  background-color: #ffffff;
  background-image: none;
  border: 1px solid #cccccc;
  border-radius: 4px;
  -webkit-box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);
          box-shadow: inset 0 1px 1px rgba(0, 0, 0, 0.075);
  -webkit-transition: border-color ease-in-out 0.15s, box-shadow ease-in-out 0.15s;
          transition: border-color ease-in-out 0.15s, box-shadow ease-in-out 0.15s;
}
._oab_button {
  display: table-cell;
  min-width:40px;
  height:34px;
  padding: 6px 3px;
  margin-bottom: 0;
  font-size: 1em;
  font-weight: normal;
  line-height: 1.428571429;
  text-decoration: none;
  text-align: center;
  white-space: nowrap;
  vertical-align: middle;
  cursor: pointer;
  background-image: none;
  border: 1px solid transparent;
  border-radius: 4px;
  -webkit-user-select: none;
     -moz-user-select: none;
      -ms-user-select: none;
       -o-user-select: none;
          user-select: none;
  color: #ffffff;
  background-color: #428bca;
  border-color: #357ebd;
}
</style>'

_oab.instantill_template = '
<div class="_oab_panel" id="_oab_inputs">
  <p id="_oab_intro">
    If you need <span class="_oab_paper">an article</span> you can request it from any library in the world through Interlibrary loan.
    <br>Start by entering a full <span class="_oab_paper">article</span> title, DOI or URL:<br>
  </p> 
  <p><input class="_oab_form" type="text" id="_oab_input" placeholder="e.g. World Scientists Warning of a Climate Emergency" aria-label="Enter a search term" style="box-shadow:none;"></input></p>
  <p><a class="_oab_find _oab_button _oab_loading" href="#" aria-label="Search" style="min-width:150px;">Find <span class="_oab_paper">article</span></a></p>
  <div id="_oab_book_or_other"></div>
  <div id="_oab_advanced_account_info"></div>
</div>

<div class="_oab_panel" id="_oab_findings" style="display:none;">
  <div id="_oab_citation"><h2>A title</h2><p><b>And citation string, OR demo title OR Unknown <span class="_oab_paper">article</span> and refer to library</b></p></div>
  <p><a class="_oab_wrong" href="#">This is not the <span class="_oab_paper">article</span> I searched</a></p>
  <div class="_oab_section" id="_oab_sub_available">
    <h3>We have an online copy instantly available</h3>
    <p>You should be able to access it on the publisher\'s website.</p>
    <p><a target="_blank" id="_oab_sub_url" href="#"><b>Open <span class="_oab_paper">article</span> in a new tab</b></a></p>
  </div>
  <div class="_oab_section" id="_oab_oa_available">
    <h3><br>There is a free, instantly accessible copy online</h3>
    <p>It may not be the final published version and may lack graphs or figures making it unsuitable for citations.</p>
    <p><a id="_oab_url" target="_blank" href="#"><b>Open <span class="_oab_paper">article</span> in a new tab</b></a></p>
  </div>
  <div class="_oab_section" id="_oab_ask_library">
    <h3><br>Ask the library to digitally send you the published full-text via Interlibrary Loan</h3>
    <div id="_oab_cost_time"><p>It is free to you, and we\'ll usually email the link within 24 hours.<br></p></div>
    <div id="_oab_collect_email">
      <p id="_oab_terms_note"><input type="checkbox" id="_oab_read_terms"> I have read the <a id="_oab_terms_link" target="_blank" href="#"><b>terms and conditions</b></a></p>
      <p><input placeholder="Your university email address" id="_oab_email" type="text" class="_oab_form"></p>
    </div>
    <p><a class="_oab_submit _oab_button _oab_loading" href="#" style="min-width:150px;">Complete request</a></p>
  </div>
</div>

<div class="_oab_panel" id="_oab_metadata" style="display:none;">
  <h2>Sorry we didn\'t find that!</h2>
  <p id="_oab_doi_not_in_crossref" style="display:none;">The DOI <span id="_oab_bad_doi">you entered</span> does not appear in Crossref</p>
  <p>Please provide or amend the <span class="_oab_paper">article</span> details.</p>
  <p><span class="_oab_paper">Article</span> title (required)<br><input class="_oab_form" id="_oab_title" type="text" placeholder="e.g The State of OA: A large-scale analysis of Open Access"></p>
  <p>Journal title (required)<br><input class="_oab_form" id="_oab_journal" type="text" placeholder="e.g. Nature"></p>
  <p>Year of publication (required)<br><input class="_oab_form" id="_oab_year" type="text" placeholder="e.g 1992"></p>
  <p><span class="_oab_paper">Article</span> DOI or URL<br><input class="_oab_form" id="_oab_doi" type="text" placeholder="e.g 10.1126/scitranslmed.3008973"></p>
  <p><a href="#" class="_oab_find _oab_button _oab_loading _oab_continue" style="min-width:150px;">Continue</a></p>
  <p>
    <a href="#" class="_oab_restart">Try again</a>
    <span id="_oab_advancedform" style="display:none;"></span>
  </p>
</div>

<div class="_oab_panel" id="_oab_done" style="display:none;">
  <div id="_oab_done_header">
    <h2>Thanks! Your request has been received.</h2>
    <p>And confirmation code and tell we will email soon - OR sorry we could not create an ILL, and refer back to library if possible.</p>
    <p>"Do another" link below would change to "Try again" in event of sorry.</p>
  </div>
  <p><a href="#" class="_oab_restart" id="_oab_done_restart">Do another</a></p>
</div>
<div id="_oab_error"></div>
<div id="_oab_pilot"></div>'

_oab.shareyourpaper_template = '
<div class="_oab_panel" id="_oab_inputs">
  <h2>Make your research visible and see 30% more citations</h2>
  <p id="_oab_lib_info">We can help you make your paper Open Access, for free, wherever you publish. It\'s legal and takes just minutes.</p>
  <p>Join millions of researchers sharing their papers freely with colleagues and the public.</p>
  <h3>Start by entering the DOI of your paper</h3>
  <p>We\'ll gather information about your paper and find the easiest way to share it.</p>
  <p><input class="_oab_form" type="text" id="_oab_input" placeholder="e.g. 10.1126/scitranslmed.3001922" aria-label="Enter a search term" style="box-shadow:none;"></input></p>
  <p><a class="_oab_find _oab_button _oab_loading" href="#" id="_oab_find" aria-label="Search" style="min-width:150px;">Next</a></p>
  <p><a id="_oab_nodoi" href="mailto:help@openaccessbutton.org?subject=Help%20depositing%20my%20paper&body=Hi%2C%0D%0A%0D%0AI\'d%20like%20to%20deposit%3A%0D%0A%0D%0A%3C%3CPlease%20insert%20a%20full%20citation%3E%3E%0D%0A%0D%0ACan%20you%20please%20assist%20me%3F%0D%0A%0D%0AYours%20sincerely%2C">My paper doesn\'t have a DOI</a></p>
</div>

<div class="_oab_panel" id="_oab_permissions" style="display:none;">
  <div class="_oab_section _oab_oa">
    <h2>Your paper is already freely available!</h2>
    <p>Great news, you\'re already getting the benefits of sharing your work! Your publisher or co-author have already shared it.</p>
    <p><a target="_blank" href="#" class="_oab_oa_url _oab_button" style="min-width:150px;">See free version</a></p>
    <p><a href="#" class="_oab_restart">Do another</a></p>
  </div>

  <div class="_oab_section _oab_permission_required">
    <h2>You may share your paper if you ask the journal</h2>
    <p>Unlike most, <span class="_oab_journal">the journal</span> requires that you ask them before you share your paper freely. 
    Asking only takes a moment as we find out who to contact and have drafted an email for you.</p>
    <p><a target="_blank" id="_oab_reviewemail" href="#" class="_oab_button" style="min-width:150px;">Review Email</a></p>
    <p><a target="_blank" id="_oab_permissionemail" href="#">I\'ve got permission now!</a></p>
  </div>  

  <div class="_oab_section _oab_oa_deposit">
    <h2>Your paper is already freely available!</h2>
    <p>Great news, you\'re already getting the benefits of sharing your work! Your publisher or co-author have already shared a <a class="_oab_oa_url" target="_blank" href="#"><u>freely available copy</u></a>.</p>
    <h3 class="_oab_section _oab_get_email">Give us your email to confirm deposit</h3>
  </div>

  <div class="_oab_section _oab_archivable">
    <h2>You can freely share your paper now!</h2>
    <p><span class="_oab_library">The library has</span> checked and <span class="_oab_journal">the journal</span> encourages you to freely share <span class="_oab_your_paper">your paper</span> so colleagues and the public can freely read and cite it. <span class="_oab_refs"></span></p>
    <div id="_oab_not_pdf">
      <h3><span>&#10003;</span> Find the manuscript the journal accepted. It\'s not a PDF from the journal site</h3>
      <p>This is the only version you\'re able to share legally. The accepted manuscript is the word file or Latex export you sent the publisher after peer-review and before formatting (publisher proofs).</p>
      <h3><span>&#10003;</span> Check there aren\’t publisher logos or formatting</h3>
      <p>It\'s normal to share accepted manuscripts as the research is the same. It\'s fine to save your file as a pdf, make small edits to formatting, fix typos, remove comments, and arrange figures.</p>
    </div>
    <h3 class="_oab_section _oab_get_email"><span>&#10003;</span> Tell us your email</h3>
  </div>

  <div class="_oab_section _oab_dark_deposit">
    <h2>You can share your paper!</h2>
    <p>We checked and unfortunately <span class="_oab_journal">the journal</span> won\'t let you share <span class="_oab_your_paper">your paper</span> freely with everyone. <span class="_oab_refs"></span><br><br>
    The good news is the library can still legally make your paper much easier to find and access. We\'ll put the publisher PDF in <span class="_oab_repo">ScholarWorks</span> and then share it on your behalf whenever it is requested.</p>
    <h3 class="_oab_section _oab_get_email">All we need is your email</h3>
  </div>

  <div class="_oab_section _oab_get_email">
    <p><input class="_oab_form" type="text" id="_oab_email" placeholder="" aria-label="Enter your email" style="box-shadow:none;"></input></p>
    <p class="_oab_section _oab_oa_deposit">We\'ll use this to send you a link. By depositing, you\'re agreeing to the <span class="_oab_terms">terms</span>.</p>
    <p class="_oab_section _oab_archivable">We\'ll only use this if something goes wrong.<br>
    <p class="_oab_section _oab_dark_deposit">We\'ll only use this to send you a link to your paper when it is in <span class="_oab_repo">ScholarWorks</span>. By depositing, you\'re agreeing to the <span class="_oab_terms">terms</span>.</p>
  </div>

  <div class="_oab_section _oab_archivable">
    <h3>We\'ll check it\'s legal, then promote, and preserve your work</h3>
    <p><input type="file" name="file" id="_oab_file" class="_oab_form"></p>
    <p>By depositing you\'re agreeing to the <span class="_oab_terms">terms</span> and to license your work <span id="_oab_licence">CC-BY</span>.</p>
  </div>
  
  <div class="_oab_section _oab_oa_deposit _oab_archivable _oab_dark_deposit">
    <p><a target="_blank" href="#" class="_oab_deposit _oab_button _oab_loading" style="min-width:150px;">Deposit</a></p>
  </div>
</div>

<div class="_oab_panel" id="_oab_done" style="display:none;">
  <div class="_oab_done" id="_oab_confirm">
    <h2>Hmmm, something looks wrong</h2>
    <p>You\'re nearly done. It looks like what you uploaded is a publisher\'s PDF which your journal prohibits legally sharing.<!-- It can only be shared on a limited basis.--><br><br>
    We just need the version accepted by the journal to make your work available to everyone.</p>
    <p><a href="#" class="_oab_reload _oab_button" style="min-width:150px;">Try uploading again</a></p>
    <p><a href="#" class="_oab_confirm">My upload was an accepted manuscript</a></p>
  </div>

  <div class="_oab_done" id="_oab_check">
    <h2>We\'ll double check your paper</h2>
    <p>You\'ve done your part for now. Hopefully, we\'ll send you a link soon. First, we\'ll check in the next working day to make sure it\'s legal to share.</p>
  </div>
  
  <div class="_oab_done" id="_oab_partial">
    <h2>Congrats, you\'re done!</h2>
    <p>Check back soon to see your paper live, or we\'ll email you with issues.</p>
  </div>
  
  <div class="_oab_done" id="_oab_zenodo">
    <h2>Congrats! Your paper will be available to everyone, forever!</h2>
    <div id="_oab_zenodo_embargo"></div>
    <p><input id="_oab_zenodo_url" class="_oab_form" type="text" style="box-shadow:none;" value=""></input></p>
    <p>You can now put the link on your website, CV, any profiles, and ResearchGate.</p>
  </div>

  <div class="_oab_done" id="_oab_redeposit">
    <h2>Congrats, you\'re done!</h2>
    <p>Check back soon to see your paper live, or we\'ll email you with issues.</p>
  </div>

  <div class="_oab_done" id="_oab_success">
    <h2>Hurray, you\'re done!</h2>
    <p>We\'ll email you a link to your paper in <span class="_oab_repo">ScholarWorks</span> soon. Next time, before you publish check to see if your journal allows you to have the most impact by making your research available to everyone, for free.</p>
  </div>

  <div class="_oab_done" id="_oab_review">
    <h2>You\'ve done your part</h2>
    <p>All that\'s left to do is wait. Once the journal gives you permission to share, come back and we\'ll help you finish the job.</p>
  </div>
  
  <p><a href="#" class="_oab_restart" id="_oab_done_restart">Do another</a></p>
</div>
<div id="_oab_error"></div>
<div id="_oab_pilot"></div>'

# can pass in a key/value pair, or key can be a config object, in which case val can optionally be a user ID string, 
# or key can be a user ID string and val must be empty, or key and val can both be empty and config will attempt 
# to be retrieved from setup, or localstorage and/or from the API if a user ID is available from setup
_oab.prototype.configure = (key, val, build, demo) ->
  if typeof key is 'string' and not val? and key.startsWith '{'
    try key = JSON.parse key
  if typeof key is 'string' and not val? and (not this.uid? or this.uid is 'anonymous')
    this.uid = key
    key = true
  if (key is true or not key?) and not val? and JSON.stringify(this.config) is '{}'
    try
      if this.local isnt false # can be disabled if desired, by setting local to false at setup or in url param
        lc = JSON.parse localStorage.getItem '_oab_config_' + this.plugin
        if typeof lc is 'object' and lc isnt null
          this.config = lc 
          console.log 'Config retrieved from local storage'
    if this.uid and this.uid isnt 'anonymous' and JSON.stringify(this.config) is '{}' # should a remote call always be made to check for superseded config if one is not provided at startup?
      _L.jx this.api + '/' + (if this.plugin is 'instantill' then 'ill' else 'deposit') + '/config?uid='+this.uid, undefined, (res) => console.log('Config retrieved from API'); this.configure(res)
  if typeof key is 'object'
    this.uid = val if typeof val is 'string'
    for d of key
      if not this.config[d]? or this.config[d] isnt key[d]
        build = true if build isnt false
        this.config[d] = if key[d] is 'true' then true else if key[d] is 'false' then false else key[d]
  else if key? and val?
    this.config[key] = if val is 'true' then true else if val is 'false' then false else val
  for k of this.config
    # is it safe to ignore certain configs if they default empty or false?
    delete this.config[k] if not this.config[k]? or this.config[k] is false or ((typeof this.config[k] is 'string' or Array.isArray(this.config[k])) and this.config[k].length is 0)
  try
    localStorage.setItem('_oab_config_' + this.plugin, JSON.stringify this.config) if JSON.stringify(this.config) isnt '{}'
  if this.css isnt false and this.config.css is true
    this.css = false
    build = true
  if this.bootstrap isnt false and this.config.bootstrap is true
    this.bootstrap = false
    build = true
  if build isnt false
    this.element ?= '#' + this.plugin
    _L.remove '#_oab_css'
    if typeof this.css is 'string' and this.css isnt 'false'
      this.css = '<style id="_oab_css">' + this.css + '</style>' if not this.css.startsWith '<style>'
      _L.append this.element, this.css
    else if this.bootstrap is true
      this.template = this.template.replace(/_oab_button/g,'_oab_button btn btn-primary').replace(/_oab_form/g,'_oab_form form-control')
    else if this.bootstrap is false and this.template.indexOf('btn-primary') isnt -1
      this.template = this.template.replace(/ btn btn-primary/g,'').replace(/ form-control/g,'')
      _L.remove(this.element) if _L.gebi this.element
    if not _L.gebi '_oab_inputs'
      _L.append this.element, this.template
    _L.each '._oab_paper', (el) =>
      cs = el.innerHTML
      if this.config.saypaper
        if cs.indexOf('aper') is -1
          el.innerHTML = (if cs is 'an article' then 'a paper' else if cs is 'article' then 'paper' else 'Paper')
      else if cs.indexOf('aper') isnt -1
        el.innerHTML = (if cs is 'a paper' then 'an article' else if cs is 'paper' then 'article' else 'Article')
    if this.config.pilot
      pilot = '<p><br>Notice a change? We\'re testing a simpler and faster way to ' + (if this.plugin is 'instantill' then 'get' else 'deposit') + ' your ' + (if this.config.saypaper then 'paper' else 'article') + (if this.plugin is 'instantill' then '' else 's') + '. You can '
      pilot += '<a href="mailto:' + this.cml() + '">give feedback</a> or '
      if this.plugin is 'instantill'
        pilot += '<a class="_oab_ping" message="instantill_use_the_old_form" target="_blank" href="' + (if this.config.advancedform then this.config.advancedform else if this.config.ill_redirect_base_url then this.config.ill_redirect_base_url else 'mailto:'+this.cml()) + '">use the old form</a>.</p>'
      else
        pilot += '<a class="_oab_ping" message="shareyourpaper_use_the_old_form" target="_blank" href="' + (if this.config.old_way then (if this.config.old_way.indexOf('@') isnt -1 then 'mailto:' else '') + this.config.old_way else 'mailto:' + this.cml()) + '">use the old way</a>.</p>'
      _L.html '#_oab_pilot', pilot
    else
      _L.html '#_oab_pilot', ''

    # shareyourpaper exclusive configs
    if this.plugin is 'shareyourpaper'
      if this.cml()? and el = _L.gebi '_oab_nodoi'
        el.setAttribute 'href', el.getAttribute('href').replace('help@openaccessbutton.org', this.cml())
      if not this.config.not_a_library
        _L.html '._oab_library', 'We have'
        _L.html '#_oab_lib_info', 'Share your paper with help from the library in ' + (this.config.repo_name ? 'ScholarWorks') + '. Legally, for free, in minutes. '

    else if this.plugin is 'instantill'
      if this.config.book or this.config.other
        boro = '<p>Need '
        boro += 'a <a href="' + this.config.book + '">book chapter</a>' if this.config.book
        boro +=  (if this.config.book then ' or ' else ' ') + '<a href="' + this.config.other + '">something else</a>' if this.config.other
        _L.html '#_oab_book_or_other', boro + '?</p>'
      else
        _L.html '#_oab_book_or_other', ''
      if this.config.advancedform or this.config.viewaccount or this.config.illinfo
        aai = '<p>Or '
        if this.config.advancedform
          _L.show '#_oab_advancedform', ' or <a href="' + this.config.advancedform + '">use full request form</a>'
          aai += '<a href="' + this.config.advancedform + '">use full request form</a>'
          if this.config.viewaccount and this.config.illinfo
            aai += ', '
          else if this.config.viewaccount or this.config.illinfo
            aai += ' and '
        if this.config.viewaccount
          aai += '<a href="' + this.config.viewaccount + '">view account</a>'
          aai += ' and ' if this.config.illinfo
        aai += '<a href="' + this.config.illinfo + '">learn about Interlibrary Loan</a>' if this.config.illinfo
        _L.html '#_oab_advanced_account_info', aai + '</p>'
      else
        _L.html '#_oab_advanced_account_info', ''
        _L.hide '#_oab_advancedform'

    # would be better to make _L handle the bind so that this.find works rather than having to wrap it in a function that passes context
    _L.listen 'enter', '#_oab_input', (e) => this.find(e)
    _L.listen 'enter', '#_oab_email', (e) => this.validate(e)
    _L.listen 'click', '._oab_find', (e) => this.find(e)
    _L.listen 'click', '._oab_submit', (e) => this.submit(e)
    _L.listen 'click', '._oab_restart', (e) => this.restart(e)
    _L.listen 'click', '._oab_ping', (e) => this.ping(_L.get e.target, 'message')
    _L.listen 'click', '._oab_wrong', (e) => 
      e.preventDefault()
      this.ping '_wrong_article'
      this.metadata()
    _L.listen 'click', '._oab_reload', (e) => 
      e.preventDefault()
      this.file = false
      this.permissions()
    _L.listen 'click', '._oab_confirm', (e) => e.preventDefault(); this.data.confirmed = true; this.deposit()
    _L.listen 'click','#_oab_reviewemail', (e) => this.done 'review'
    _L.listen 'click','._oab_deposit', (e) => this.deposit(e)
  
  if el = _L.gebi '_oab_config'
    el.innerHTML = JSON.stringify this.config, '', 2
  this.demo(undefined, demo) if demo
  return this.config

@shareyourpaper = (opts) -> opts ?= {}; opts.plugin = 'shareyourpaper'; return new _oab(opts);
@instantill = (opts) -> opts ?= {}; opts.plugin = 'instantill'; return new _oab(opts);