
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
    el = _L.clone el # gets rid of all listeners so we don't end up with dups - but note, gets rid of ALL. TODO use a wrapper to manage these independently
    el.addEventListener action, (e) -> wfn(e)
_L.show = (els, html, append) ->
  _L.each els, (el) -> 
    if html
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
      catch
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
