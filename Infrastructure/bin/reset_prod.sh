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

# Change MLBparks route 
oc patch route/mlbparks \
    -p '{"spec":{"to":{"name":"mlbparks-green"}}}' \
    -n $GUID-parks-prod || echo "MLBParks already green"

# Change National Parks route 
oc patch route/nationalparks \
    -p '{"spec":{"to":{"name":"nationalparks-green"}}}' \
    -n $GUID-parks-prod || echo "NationalParks already green"

# Switch parksmap frontend to green
oc patch route/parksmap \
    -p '{"spec":{"to":{"name":"parksmap-green"}}}' \
    -n $GUID-parks-prod || echo "ParksMap already green"
