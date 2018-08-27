#!/bin/bash
# Reset Production Project (initial active services: Blue)
# This sets all services to the Blue service so that any pipeline run will deploy Green
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Resetting Parks Production Environment in project ${GUID}-parks-prod to Blue Services"

# Reset MLBParks Production to blue deployment 
# Delete configmap and re-create with Blue APPNAME
oc delete configmap mlbparks-config -n ${GUID}-parks-prod --ignore-not-found=true
oc create configmap mlbparks-config --from-literal=APPNAME='MLB Parks (Blue)' -n ${GUID}-parks-prod
# Delete and re-create backend service to point to blue deployment
oc delete service mlbparks -n ${GUID}-parks-prod --ignore-not-found=true
oc expose dc mlbparks-blue --name=mlbparks --port 8080 --labels=type=parksmap-backend,activeApp=mlbparks-blue -n ${GUID}-parks-prod

# Reset NationalParks Production to blue deployment 
# Delete configmap and re-create with Blue APPNAME
oc delete configmap nationalparks-config -n ${GUID}-parks-prod --ignore-not-found=true
oc create configmap nationalparks-config --from-literal=APPNAME='National Parks (Blue)' -n ${GUID}-parks-prod
# Delete and re-create backend service to point to blue deployment
oc delete service nationalparks -n ${GUID}-parks-prod --ignore-not-found=true
oc expose dc nationalparks-blue --name=nationalparks --port 8080 --labels=type=parksmap-backend,activeApp=nationalparks-blue -n ${GUID}-parks-prod

# Reset ParksMap Production to blue deployment 
# Delete configmap and re-create with Blue APPNAME
oc delete configmap parksmap-config -n ${GUID}-parks-prod --ignore-not-found=true
oc create configmap parksmap-config --from-literal=APPNAME='ParksMap (Blue)' -n ${GUID}-parks-prod
# Patch route to point to blue deployment
oc patch route parksmap -n ${GUID}-parks-prod -p '{"spec":{"to":{"name":"parksmap-blue"}}}'