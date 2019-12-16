
API.add 'service/oab/permissions', get: () -> return API.service.oab.permissions this.queryParams

# this has its own method because later we will be adding better permissions and file checking in here
# perhaps this should save to catalogue too, but consider how that works when called from find
# also could look up in catalogue if could already be in there

API.service.oab.permissions = (meta,file) ->
  try
    perms = sherpa: API.use.sherpa.romeo.find(if meta.issn then {issn:meta.issn} else {title:meta.journal})
    # only uses old sherpa for now
    # if sherpa gives green yellow or blue then we can get accept a file
    # actually green or blue allows accepted version, yellow allows preprint
    perms.acceptable = perms.sherpa?.color? and perms.sherpa.color in ['green','yellow','blue']
    return perms
  catch
    return undefined