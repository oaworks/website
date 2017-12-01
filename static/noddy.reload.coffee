
_loaded = Date.now()
reload = () ->
  $.ajax
    type: 'GET',
    url: noddy.api + '/reload/' + (if _reload? then _reload else noddy?.service)
    success: (data) ->
      if (dd = data?.updatedAt ? data?.createdAt)? and dd > _loaded
        _loaded = data.updatedAt
        window.location = window.location.href

try noddy.reload = reload

@_reloadpid = undefined
if (noddy?.debug or _reload?) and not _reloadpid? and (_reload? or noddy?.service)
  console.log 'Starting reloader'
  _reloadpid = setInterval reload, 2000