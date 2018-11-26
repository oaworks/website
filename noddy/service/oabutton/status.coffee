

API.service.oab.status = () ->
  return
    requests: oab_request.count()
    test: oab_request.count undefined, {test:true}
    help: oab_request.count undefined, {status:'help'}
    moderate: oab_request.count undefined, {status:'moderate'}
    progress: oab_request.count undefined, {status:'progress'}
    hold: oab_request.count undefined, {status:'hold'}
    refused: oab_request.count undefined, {status:'refused'}
    received: oab_request.count undefined, {status:'received'}
    supports: oab_support.count()
    availabilities: oab_availability.count()
    users: Users.count undefined, {exists:{field:"roles.openaccessbutton"}}
    requested: oab_request.count 'user.id', {exists:{field:'user.id'}}
    #requested: oab_request.aggregate( [ { $group: { _id: "$user"}  } ] ).length # need an alternative to aggregate
