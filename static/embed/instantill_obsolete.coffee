
@_ill = 
  api: if window.location.host.indexOf('dev.openaccessbutton.org') isnt -1 then 'https://dev.api.cottagelabs.com/service/oab' else 'https://api.openaccessbutton.org'
  uid: 'anonymous'
  config: {}
  element: '#instantill'
  data: {} # the data obj to send to backend
  f: {} # the result of the find request to the backend
  template: undefined # these are set below
  css: undefined # or can be set to false to include no css, or a string of css <style> content
  bootstrap: true # if true and css is false then bootstrap classes will be added to buttons and form elements

_cml = () -> return _ill.config.problem_email ? _ill.config.email ? _ill.config.adminemail ? ''
_lib_contact = () -> return 'Please try ' + (if _cml() then '<a href="mailto:' + _cml() + '">contacting your library</a>' else 'contacting your library') + ' directly'

_ill._loading = false
_ill.loading = (load) ->
  if load isnt true and (_ill._loading or load is false)
    try clearInterval _ill._loading
    _ill._loading = false
    _L.each '._ill_loading', (el) -> 
      if _L.has el, '_ill_continue'
        el.innerHTML = 'Continue'
      else if _L.has el, '_ill_submit'
        el.innerHTML = 'Complete request'
      else
        el.innerHTML = 'Find ' + if _ill.config.saypaper then 'paper' else 'article'
  else
    _L.html '._ill_find', 'Searching .'
    _L.html '._ill_submit', 'Submitting .'
    _ill._loading = setInterval (() ->
      for button in _L.gebc '._ill_loading'
        dots = button.innerHTML.split '.'
        if dots.length >= 4
          button.innerHTML = dots[0]
        else
          button.innerHTML = button.innerHTML + ' .'
      ), 700

_ill.restart = (e, val) ->
  try e.preventDefault()
  _ill.data = {}
  _ill.f = {}
  _ill.loading false
  _L.hide '._ill_panel'
  _L.show '#_ill_inputs'
  _ill.setup()
  if val
    _L.set '#_ill_input', val
    setTimeout (() -> _ill.find()), 200
  else
    _L.set '#_ill_input', ''

_ill.demo = (e, val, panel, finding) ->
  # useful for demo/test, just does a restart but uses the config demo val if one is present
  try e.preventDefault()
  if val
    val = undefined if typeof val isnt 'string'
    val ?= _ill.config.val
    _ill.restart undefined, val
  _ill.panel(panel) if panel?
  _ill.finding(finding) if finding?
  
_ill.ping = (what) ->
  try
    url = if api.indexOf('dev.') isnt -1 then 'https://dev.api.cottagelabs.com' else 'https://api.cottagelabs.com'
    url += '/ping.png?service=openaccessbutton&action=' + what + '&from=' + _ill.uid
    url += '&pilot=' + _ill.config.pilot if _ill.config.pilot
    url += '&live=' + _ill.config.live if _ill.config.live
    _L.jx url

_ill.panel = (panel) ->
  if he = _L.gebi '_ill_' + (if panel.startsWith('_ill_') then panel.replace('_ill_') else panel)
    _L.hide '._ill_panel'
    _L.show he

_ill.finding = (finding) ->
  # useful for demo/test, just shows a specific finding section within the findings panel
  if fe = _L.gebi '_ill_' + (if finding.startsWith('_ill_') then finding.replace('_ill_') else finding)
    _L.hide '._ill_finding'
    _L.show fe

_ill.submit_after_metadata = false
_ill.submit = (e) ->
  try e.preventDefault()
  if not _ill.data.email and _L.gebi '#_ill_email'
    _ill.validate()
  else if JSON.stringify(_ill.f) is '{}' or (not _ill.f.metadata?.title or not _ill.f.metadata?.journal or not _ill.f.metadata?.year)
    if _ill.submit_after_metadata
      _ill.done false
    else
      _ill.submit_after_metadata = true
      _ill.metadata()
  else
    _ill.loading()
    _L.hide '#_ill_error'
    data = {match: _ill.f.input, email:_ill.data.email, from: _ill.uid, plugin: 'instantill', embedded: window.location.href}
    data.config = _ill.config
    data.metadata = _ill.f.metadata ? {}
    for k in ['title','journal','year','doi']
      data.metadata[k] = _ill.data[k] if not data.metadata[k] and _ill.data[k]
      if data.metadata.doi and data.metadata.doi.indexOf('http') is 0
        data.metadata.url = data.metadata.doi
        delete data.metadata.doi
    nfield = if _ill.config.notes then _ill.config.notes else 'notes'
    data[nfield] = 'The user provided some metadata. ' if _ill.data.usermetadata
    data.pilot = _ill.config.pilot if _ill.config.pilot
    data.live = _ill.config.live if _ill.config.live
    if _ill.f?.ill?.subscription or _ill.f?.availability
      if typeof data[nfield] isnt 'string' then data[nfield] = '' else data[nfield] += ' '
      if _ill.f.ill?.subscription
        data[nfield] += 'Subscription check done, found ' + (_ill.f.ill.subscription.url ? (if _ill.f.ill.subscription.journal then 'journal' else 'nothing')) + '. '
      if _ill.f.metadata?
        data[nfield] += 'OA availability check done, found ' + (_ill.f.url ? 'nothing') + '. '
    if _ill.f?.ill?.openurl and _ill.config.openurl isnt false and not data.email
      data.forwarded = true
    _L.post(
      api+'/ill'
      data
      (res) -> _ill.done res
      () -> _ill.done false
    )

_ill.validate = () ->
  if _ill.f.ill?.terms and not _L.checked '#_ill_read_terms'
    _L.show '#_ill_error', '<p>Please agree to the terms first.</p>'
  else
    email = (_L.get('#_ill_email') ? '').trim()
    if not email.length
      _L.show '#_ill_error', '<p>Please provide your university email address.</p>'
      _L.css '#_ill_email', 'border-color', '#f04717'
      _L.gebi('#_ill_email').focus()
    else
      _ill.loading()
      _L.post(
        api + '/validate?uid=' + _ill.uid + '&email=' + email
        _ill.config
        (res) ->
          _ill.loading false
          if res is true
            _ill.data.email = _L.get('#_ill_email').trim()
            _ill.submit()
          else if res is 'baddomain'
            _L.show '#_ill_error', '<p>Please try again with your university email address.</p>'
          else
            _L.show '#_ill_error', '<p>Sorry, your email does not look right. ' + (if res isnt false then 'Did you mean ' + res + '? ' else '') + 'Please check and try again.</p>'
        () -> 
          _ill.data.email = _L.get('#_ill_email').trim()
          _ill.submit()
      )

_ill.metadata = (submitafter) ->
  for m in ['title','year','journal','doi']
    if _ill.f.metadata[m]?
      _L.set '#_ill_'+m, _ill.f.metadata[m].split('(')[0].trim()
  if _ill.f?.doi_not_in_crossref
    _L.html '#_ill_bad_doi', _ill.f.doi_not_in_crossref
    _L.show '#_ill_doi_not_in_crossref'
  _L.hide '._ill_panel'
  _L.show '#_ill_metadata'

_ill.openurl = () ->
  _L.post(
    api+'/ill/openurl?uid='+_ill.uid + (if _ill.data.usermetadata then '&usermetadata=true' else '')
    _ill.f.metadata # TODO need to be able to pass the config as well
    (res) -> window.location = res
    (data) ->
      try
        window.location = _ill.f.ill.openurl
      catch err
        _ill.done undefined, 'InstantILL_openurl_couldnt_create_ill'
  )

_ill.done = (res, msg) ->
  if _ill.f.ill?.openurl and _ill.config.openurl #and not _ill.data.email
    if _ill.submit_after_metadata
      _ill.openurl()
    else
      window.location = _ill.f.ill.openurl
  else
    _L.hide '._ill_panel'
    if res
      _L.html '#_ill_done_header', '<h3>Thanks! Your request has been received</h3><p>Your confirmation code is: ' + res + ', this will not be emailed to you. The ' + (if _ill.config.saypaper then 'paper' else 'article') + ' will be sent to ' + _ill.data.email + ' as soon as possible.</p>'
    else
      _L.html '#_ill_done_header', '<h3>Sorry, we were not able to create an Interlibrary Loan request for you.</h3><p>' + _lib_contact() + '</p>'
      _L.html '#_ill_done_restart', 'Try again'
      _ill.ping msg ? 'InstantILL_couldnt_submit_ill'
      setTimeout _ill.restart, 6000
    _L.show '#_ill_done'

_ill.findings = (data) ->
  _ill.f = data if data?
  if ct = _ill.f.metadata?.crossref_type
    if ct not in ['journal-article','proceedings-article','posted-content']
      if ct in ['book-section','book-part','book-chapter']
        err = '<p>Please make your request through our ' + (if _ill.config.book then '<a href="' + _ill.config.book + '">book form</a>' else 'book form')
      else
        err = '<p>We can only process academic journal articles, please use another form.'
      _L.show '#_ill_error', err + '</p>'
      return

  _L.hide '#_ill_error'
  _L.hide '._ill_panel'
  _L.hide '._ill_finding'
  _ill.loading false

  if _ill.config.resolver
    # new setting to act as a link resolver, try to pass through immediately if sub url, OA url, or lib openurl are available
    # TODO confirm if this should send an ILL to the backend first, as a record, or maybe just a pinger
    # also check if could forward the user to the new page before the send to backend succeeds / errors
    data = {match: _ill.f.input, from: _ill.uid, plugin: 'instantill', embedded: window.location.href}
    data.config = _ill.config
    data.metadata = _ill.f.metadata ? {}
    data.pilot = _ill.config.pilot if _ill.config.pilot
    data.live = _ill.config.live if _ill.config.live
    if _ill.f.ill?.subscription?.url
      data.resolved = 'subscription'
      _L.post(api+'/ill', data, (() -> window.location = _ill.f.ill.subscription.url), (() -> window.location = _ill.f.ill.subscription.url))
    else if _ill.f.url
      data.resolved = 'open'
      _L.post(api+'/ill', data, (() -> window.location = _ill.f.url), (() -> window.location = _ill.f.url))
    else if _ill.f.ill?.openurl
      data.resolved = 'library'
      _L.post(api+'/ill', data, (() -> window.location = _ill.f.ill.openurl), (() -> window.location = _ill.f.ill.openurl))

  _L.show '#_ill_findings'
  if _ill.f.ill?.error
    _L.show '#_ill_error', '<p>Please note, we encountered errors querying the following subscription services: ' + _ill.f.ill.error.join(', ') + '</p>'
  if _ill.f.metadata?.title? or _ill.f.ill?.subscription?.demo
    citation = '<h2>' + (if _ill.f.ill?.subscription?.demo then '<Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL' else _ill.f.metadata.title) + '</h2>'
    if _ill.f.metadata.year or _ill.f.metadata.journal or _ill.f.metadata.volume or _ill.f.metadata.issue
      citation += '<p><b style="color:#666;">'
      citation += (_ill.f.metadata.year ? '') + (if _ill.f.metadata.journal or _ill.f.metadata.volume or _ill.f.metadata.issue then ', ' else '') if _ill.f.metadata.year
      if _ill.f.metadata.journal
        citation += _ill.f.metadata.journal
      else
        citation += 'vol. ' + _ill.f.metadata.volume if _ill.f.metadata.volume
        citation += (if _ill.f.metadata.volume then ', ' else '') + 'issue ' + _ill.f.metadata.issue if _ill.f.metadata.issue
      citation += '</b></p>'
    _L.html '#_ill_citation', citation

    hassub = false
    hasoa = false
    if _ill.f.ill?.subscription?.journal or _ill.f.ill?.subscription?.url
      hassub = true
      # if sub url show the url link, else show the "should be able to access on pub site
      _L.set('#_ill_sub_url', 'href', _ill.f.ill.subscription.url) if _ill.f.ill.subscription.url?
      _L.show '#_ill_sub_available'
    else if _ill.f.url
      hasoa = true
      _L.set '#_ill_url', 'href', _ill.f.url
      _L.show '#_ill_oa_available'
    if _ill.f.ill and _ill.config.ill isnt false and not ((_ill.config.noillifsub and hassub) or (_ill.config.noillifoa and hasoa))
      _L.html '#_ill_cost_time', '<p>It ' + (if _ill.config.cost then 'costs ' + _ill.config.cost else 'is free to you,') + ' and we\'ll usually email the link within ' + (_ill.config.time ? '24 hours') + '.<br></p>'
      if _ill.f.ill.terms
        _L.show '#_ill_terms_note'
        _L.set '#_ill_terms_link', 'href', _ill.f.ill.terms
      else
        _L.hide '#_ill_terms_note'
      _L.show '#_ill_ask_library'

  else if _ill.data.usermetadata
    _L.html '#_ill_citation', '<h3>Unknown ' + (if _ill.config.saypaper then 'paper' else 'article') + '</h3><p>Sorry, we can\'t find this ' + (if _ill.config.saypaper then 'paper' else 'article') + ' or sufficient metadata. ' + _lib_contact() + '</p>'
    _ill.ping 'InstantILL_unknown_article'
    setTimeout _ill.restart, 6000
  else
    _ill.metadata()

_ill.find = (e) ->
  try e.preventDefault()
  _L.hide '#_ill_error'
  if JSON.stringify(_ill.f) isnt '{}'
    for k in ['title','journal','year','doi']
      if v = _L.get '#_ill_' + k
        if _ill.data[k] isnt v
          _ill.data[k] = v
          _ill.data.usermetadata = true
    if _ill.data.year and _ill.data.year.length isnt 4
      delete _ill.data.year
      _L.show '#_ill_error', '<p>Please provide the full year e.g 2019</p>'
      return
    if not _ill.data.title or not _ill.data.journal or not _ill.data.year
      _L.show '#_ill_error', '<p>Please complete all required fields</p>'
      return
    if _ill.submit_after_metadata
      _ill.submit()
      return
      
  _ill.data.title ?= _ill.data.atitle if _ill.data.atitle
  _ill.data.doi ?= _ill.data.rft_id if _ill.data.rft_id
  if _ill.data.doi and _ill.data.doi.indexOf('10.') isnt -1 and (_ill.data.doi.indexOf('/') is -1 or _ill.data.doi.indexOf('http') is 0)
    _ill.data.url = _ill.data.doi
    delete _ill.data.doi
  if val = _L.get('#_ill_input')
    val = val.trim().replace(/\.$/,'')
    if val.length
      if val.indexOf('doi.org/') isnt -1
        _ill.data.url = val
        _ill.data.doi = '10.' + val.split('10.')[1]
      else if val.indexOf('10.') isnt -1
        _ill.data.doi = val.replace('doi:','')
      else if val.indexOf('http') is 0
        _ill.data.url = val
      else if val.indexOf(' ') isnt -1
        _ill.data.title = val
      else
        _ill.data.id = val

  if not _ill.data.doi and not _ill.data.url and not _ill.data.pmid and not _ill.data.pmcid and not _ill.data.title and not _ill.data.id
    _L.show '#_ill_error', '<p><span>&#10060;</span> Sorry please provide the full DOI, title, citation, PMID or PMC ID.</p>'
  else
    _ill.loading()
    _ill.data.config = _ill.config
    _ill.data.from ?= _ill.uid
    _ill.data.plugin ?= 'instantill'
    _ill.data.embedded ?= window.location.href
    _ill.data.pilot ?= _ill.config.pilot if _ill.config.pilot
    _ill.data.live ?= _ill.config.live if _ill.config.live
    _L.post(
      _ill.api+'/find_too'
      _ill.data
      (data) -> _ill.findings(data)
      () -> _L.show '#_ill_error', '<p>Oh dear, the service is down! We\'re aware, and working to fix the problem. ' + _lib_contact() + '</p>'
    )

_ill.template = '
<div class="_ill_panel" id="_ill_inputs">
  <p id="_ill_intro">
    If you need <span class="_ill_paper">an article</span> you can request it from any library in the world through Interlibrary loan.
    <br>Start by entering a full <span class="_ill_paper">article</span> title, DOI or URL:<br>
  </p> 
  <p><input class="_ill_form" type="text" id="_ill_input" placeholder="e.g. World Scientists Warning of a Climate Emergency" aria-label="Enter a search term" style="box-shadow:none;"></input></p>
  <p><a class="_ill_find _ill_button _ill_loading" href="#" aria-label="Search" style="min-width:150px;">Find <span class="_ill_paper">article</span></a></p>
  <div id="_ill_book_or_other"></div>
  <div id="_ill_advanced_account_info"></div>
</div>

<div class="_ill_panel" id="_ill_findings" style="display:none;">
  <div id="_ill_citation"><h2>A title</h2><p><b>And citation string, OR demo title OR Unknown <span class="_ill_paper">article</span> and refer to library</b></p></div>
  <p><a class="_ill_wrong" href="#"><b>This is not the <span class="_ill_paper">article</span> I searched.</b></a></p>
  <div class="_ill_finding" id="_ill_sub_available">
    <h3>We have an online copy instantly available</h3>
    <p>You should be able to access it on the publisher\'s website.</p>
    <p><a target="_blank" id="_ill_sub_url" href="#"><b>Open <span class="_ill_paper">article</span> in a new tab</b></a></p>
  </div>
  <div class="_ill_finding" id="_ill_oa_available">
    <h3><br>There is a free, instantly accessible copy online</h3>
    <p>It may not be the final published version and may lack graphs or figures making it unsuitable for citations.</p>
    <p><a id="_ill_url" target="_blank" href="#"><b>Open <span class="_ill_paper">article</span> in a new tab</b></a></p>
  </div>
  <div class="_ill_finding" id="_ill_ask_library">
    <h3><br>Ask the library to digitally send you the published full-text via Interlibrary Loan</h3>
    <div id="_ill_cost_time"><p>It is free to you, and we\'ll usually email the link within 24 hours.<br></p></div>
    <div id="_ill_collect_email">
      <p id="_ill_terms_note"><input type="checkbox" id="_ill_read_terms"> I have read the <a id="_ill_terms_link" target="_blank" href="#"><b>terms and conditions</b></a></p>
      <p><input placeholder="Your university email address" id="_ill_email" type="text" class="_ill_form"></p>
    </div>
    <p><a class="_ill_submit _ill_button _ill_loading" href="#" style="min-width:150px;">Complete request</a></p>
  </div>
</div>

<div class="_ill_panel" id="_ill_metadata" style="display:none;">
  <h2>Sorry we didn\'t find that!</h2>
  <p id="_ill_doi_not_in_crossref" style="display:none;">The DOI <span id="_ill_bad_doi">you entered</span> does not appear in Crossref</p>
  <p>Please provide or amend the <span class="_ill_paper">article</span> details.</p>
  <p><span class="_ill_paper">Article</span> title (required)<br><input class="_ill_form" id="_ill_title" type="text" placeholder="e.g The State of OA: A large-scale analysis of Open Access"></p>
  <p>Journal title (required)<br><input class="_ill_form" id="_ill_journal" type="text" placeholder="e.g. Nature"></p>
  <p>Year of publication (required)<br><input class="_ill_form" id="_ill_year" type="text" placeholder="e.g 1992"></p>
  <p><span class="_ill_paper">Article</span> DOI or URL<br><input class="_ill_form" id="_ill_doi" type="text" placeholder="e.g 10.1126/scitranslmed.3008973"></p>
  <p><a href="#" class="_ill_find _ill_button _ill_loading _ill_continue" style="min-width:150px;">Continue</a></p>
  <p>
    <a href="#" class="_ill_restart" style="font-weight:bold;">Try again</a>
    <span id="_ill_advancedform" style="display:none;"></span>
  </p>
</div>

<div class="_ill_panel" id="_ill_done" style="display:none;">
  <div id="_ill_done_header">
    <h2>Thanks! Your request has been received.</h2>
    <p>And confirmation code and tell we will email soon - OR sorry we could not create an ILL, and refer back to library if possible.</p>
    <p>"Do another" link below would change to "Try again" in event of sorry.</p>
  </div>
  <p><a href="#" class="_ill_restart" id="_ill_done_restart" style="font-weight:bold;">Do another</a></p>
</div>
<div id="_ill_error"></div>
<div id="_ill_pilot"></div>'

_ill.css = '
<style>
._ill_form {
  display: inline-block;
  width: 100%;
  height: 34px;
  padding: 6px 12px;
  font-size: 16px;
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
._ill_button {
  display: table-cell;
  min-width:40px;
  height:34px;
  padding: 6px 3px;
  margin-bottom: 0;
  font-size: 14px;
  font-weight: normal;
  line-height: 1.428571429;
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

# can pass in a key/value pair, or key can be a config object, in which case val can optionally be a user ID string, 
# or key can be a user ID string and val must be empty, or key and val can both be empty and config will attempt 
# to be retrieved from setup, or localstorage and/or from the API if a user ID is available from setup
_ill.configure = (key, val, build, demo) ->
  if typeof key is 'string' and not val? and key.startsWith '{'
    try key = JSON.parse key
  if typeof key is 'string' and not val? and (not _ill.uid? or _ill.uid is 'anonymous')
    _ill.uid = key
    key = true
  if (key is true or not key?) and not val? and JSON.stringify(_ill.config) is '{}'
    try
      lc = JSON.parse localStorage.getItem '_ill_config'
      if typeof lc is 'object' and lc isnt null
        _ill.config = lc 
        console.log 'Config retrieved from local storage'
    if _ill.uid and _ill.uid isnt 'anonymous' # JSON.stringify(_ill.config) is '{}' # should a remote call always be made to check for superseded config if one is not provided at startup?
      _L.jx _ill.api + '/ill/config?uid='+_ill.uid, undefined, (res) -> console.log('Config retrieved from API'); _ill.configure(res)
  if typeof key is 'object'
    _ill.uid = val if typeof val is 'string'
    for d of key
      if not _ill.config[d]?
        build = true if build isnt false
        _ill.config[d] = if key[d] is 'true' then true else if key[d] is 'false' then false else key[d]
  else if key? and val?
    _ill.config[key] = if val is 'true' then true else if val is 'false' then false else val
  for k of _ill.config
    # is it safe to ignore certain configs if they default empty or false?
    delete _ill.config[k] if not _ill.config[k]? or _ill.config[k] is false or ((typeof _ill.config[k] is 'string' or Array.isArray(_ill.config[k])) and _ill.config[k].length is 0)
  try
    localStorage.setItem('_ill_config', JSON.stringify _ill.config) if JSON.stringify(_ill.config) isnt '{}'
  if build isnt false
    _L.remove '#_ill_css'
    if typeof _ill.css is 'string' and _ill.css isnt 'false'
      _ill.css = '<style id="_ill_css">' + _ill.css + '</style>' if not _ill.css.startsWith '<style>'
      _L.append _ill.element, _ill.css
    else if _ill.bootstrap is true
      _ill.template = _ill.template.replace(/_ill_button/g,'_ill_button btn btn-primary').replace(/_ill_form/g,'_ill_form form-control')
    if not _L.gebi '_ill_inputs'
      _L.append _ill.element, _ill.template
    if _ill.config.intropara # again value seems to be backwards to name
      _L.hide '#_ill_intro'
    else
      _L.show '#_ill_intro'
    _L.each '._ill_paper', (el) ->
      cs = el.innerHTML
      if _ill.config.saypaper
        if cs.indexOf('aper') is -1
          el.innerHTML = (if cs is 'an article' then 'a paper' else if cs is 'article' then 'paper' else 'Paper')
      else if cs.indexOf('aper') isnt -1
        el.innerHTML = (if cs is 'a paper' then 'an article' else if cs is 'paper' then 'article' else 'Article')
    if _ill.config.book or _ill.config.other
      boro = '<p>Need '
      boro += 'a <a href="' + _ill.config.book + '"><b>book chapter</b></a>' if _ill.config.book
      boro +=  (if _ill.config.book then ' or ' else ' ') + '<a href="' + _ill.config.other + '"><b>something else</b></a>' if _ill.config.other
      _L.html '#_ill_book_or_other', boro + '?</p>'
    else
      _L.html '#_ill_book_or_other', ''
    if _ill.config.advancedform or _ill.config.viewaccount or _ill.config.illinfo
      aai = '<p>Or '
      if _ill.config.advancedform
        _L.show '#_ill_advancedform', ' or <a href="' + _ill.config.advancedform + '">use full request form</a>'
        aai += '<a href="' + _ill.config.advancedform + '">use full request form</a>'
        if _ill.config.viewaccount and _ill.config.illinfo
          aai += ', '
        else if _ill.config.viewaccount or _ill.config.illinfo
          aai += ' and '
      if _ill.config.viewaccount
        aai += '<a href="' + _ill.config.viewaccount + '">view account</a>'
        aai += ' and ' if _ill.config.illinfo
      aai += '<a href="' + _ill.config.illinfo + '">learn about Interlibrary Loan</a>' if _ill.config.illinfo
      _L.html '#_ill_advanced_account_info', aai + '</p>'
    else
      _L.html '#_ill_advanced_account_info', ''
      _L.hide '#_ill_advancedform'
    if _ill.config.pilot
      pilot = '<p><br>Notice a change? We\'re testing a simpler and faster way to get your ' + (if _ill.config.saypaper then 'paper' else 'article') + 's. You can '
      pilot += '<a href="mailto:' + _cml() + '">give feedback</a> or '
      pilot += '<a class="_ill_ping" message="Instantill_use_the_old_form" target="_blank" href="' + (if _ill.config.advancedform then _ill.config.advancedform else if _ill.config.ill_redirect_base_url then _ill.config.ill_redirect_base_url else 'mailto:'+_cml()) + '">use the old form</a>.</p>'
      _L.html '#_ill_pilot', pilot
    else
      _L.html '#_ill_pilot', ''
    _L.listen 'enter', '#_ill_input', _ill.find
    _L.listen 'enter', '#_ill_email', _ill.validate
    _L.listen 'click', '._ill_find', _ill.find
    _L.listen 'click', '._ill_submit', _ill.submit
    _L.listen 'click', '._ill_restart', _ill.restart
    _L.listen 'click', '._ill_ping', (e) -> _ill.ping(_L.get e.target, 'message')
    _L.listen 'click', '._ill_wrong', (e) -> 
      e.preventDefault()
      _ill.ping 'InstantILL_wrong_article'
      _ill.metadata()
  if el = _L.gebi '_ill_config'
    el.innerHTML = JSON.stringify _ill.config, '', 2
  _ill.demo(undefined, demo) if demo
  return _ill.config
    
_ill.startup = false
_ill.setup = (opts) ->
  opts ?= {}
  if _ill.startup is false
    _ill.startup = opts
  else
    opts ?= _ill.startup
  _ill[o] = opts[o] for o of opts
  _L.append('body', '<div id="' + _ill.element + '"></div>') if not _L.gebi _ill.element
  _L.html _ill.element, ''
  if window.location.search.indexOf('config=') isnt -1
    try _ill.config = JSON.parse window.location.search.split('config=')[1].split('&')[0].split('#')[0]
  if window.location.search.indexOf('config.') isnt -1
    configs = window.location.search.split 'config.'
    configs.shift()
    for c in configs
      cs = c.split '='
      if cs.length is 2
        csk = cs[0].trim()
        csv = cs[1].split('&')[0].split('#')[0].trim()
        _ill.configure csk, csv, false
  _ill.configure()
  if not _ill.config.autorun # stupidly, true means don't run it...
    _ill.config.autorunparams ?= ['doi','title','url','atitle','rft_id','journal','issn','year','author']
    _ill.config.autorunparams = _ill.config.autorunparams.replace(/"/g,'').replace(/'/g,'').split(',') if typeof _ill.config.autorunparams is 'string'
    for o in _ill.config.autorunparams
      o = o.split('=')[0].trim()
      eq = o.split('=')[1].trim() if o.indexOf('=') isnt -1
      _ill.data[eq ? o] = decodeURIComponent(window.location.search.replace('?','&').split('&'+o+'=')[1].split('&')[0].replace(/\+/g,' ')) if (window.location.search.replace('?','&').indexOf('&'+o+'=') isnt -1)
  if window.location.search.indexOf('email=') isnt -1
    _ill.data.email = window.location.search.split('email=')[1].split('&')[0].split('#')[0]
    _L.remove '#_ill_collect_email'
  if window.location.search.indexOf('panel=') isnt -1
    _ill.panel window.location.search.split('panel=')[1].split('&')[0].split('#')[0]
  _ill.find() if _ill.data.doi or _ill.data.title or _ill.data.url

@instantill = _ill.setup