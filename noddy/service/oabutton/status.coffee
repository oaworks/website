
API.service.oab.status = () ->
  return
    requests: oab_request.count()
    test: oab_request.count {test:true}
    help: oab_request.count {status:'help'}
    moderate: oab_request.count {status:'moderate'}
    progress: oab_request.count {status:'progress'}
    hold: oab_request.count {status:'hold'}
    refused: oab_request.count {status:'refused'}
    received: oab_request.count {status:'received'}
    supports: oab_support.count()
    availabilities: oab_availability.count()
    users: Users.count {"roles.openaccessbutton":'*'}
    #requested: oab_request.aggregate( [ { $group: { _id: "$user"}  } ] ).length # need an alternative to aggregate
