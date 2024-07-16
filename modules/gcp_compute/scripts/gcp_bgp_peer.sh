#!/bin/bash
# Exit if any of the intermediate steps fail
set -xe

exec &> >(tee -a modules/gcp_compute/scripts/metadata_startup.log)
eval "$(jq -r '@sh "CLOUD_ROUTER=\(.cloud_router) TENANT_ID=\(.tenant_id) REGION=\(.region) CLOUD_RTR_IP1=\(.cloud_rtr_ip1) CLOUD_RTR_IP2=\(.cloud_rtr_ip2) SUBNET=\(.subnet) PROJECT=\(.project)"')"
return_code="error"
if [[ ! ( -z "${CLOUD_ROUTER}" || -z "${CLOUD_RTR_IP1}" || -z ${SUBNET} || -z ${REGION} || -z ${PROJECT} ) ]] ; then
    result=`gcloud compute routers add-interface ${CLOUD_ROUTER} --interface-name=${CLOUD_ROUTER}"-iface1" --ip-address=${CLOUD_RTR_IP1} --subnetwork=${SUBNET} --region=${REGION} --project=${PROJECT} 2>&1`
    if [[ $result =~ "Updated" ]] ; then
        return_code="success"
    elif [[ $result =~ "Duplicate" ]] ; then
        return_code="exists"
    else
        return_code="error"
    fi
else
    return_code="empty_variables"
fi

if [[ $return_code =~ "success"  || $return_code =~ "exists" ]] ; then
    result=`gcloud compute routers add-interface ${CLOUD_ROUTER} --interface-name=${CLOUD_ROUTER}"-iface2" --ip-address=${CLOUD_RTR_IP2} --subnetwork=${SUBNET} --redundant-interface=${CLOUD_ROUTER}"-iface1" --region=${REGION} --project=${PROJECT} 2>&1`
    if [[ $result =~ "Updated" ]] ; then
        return_code="success"
    elif [[ $result =~ "Duplicate" ]] ; then
        return_code="exists"
    else
        return_code="error"
    fi
fi
echo $return_code > modules/gcp_compute/scripts/metadata_startup
# Safely produce a JSON object containing the result value.
jq -n --arg result "${return_code}" '{"result":$result}'