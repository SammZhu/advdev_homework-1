#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

oc policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-prod

# allow gading pipeline to edit + delete projects
oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-prod

# spin up mongo db via stateful set
oc new-app -f ./Infrastructure/templates/cpd-parks-prod/mongodb_services.yaml -n ${GUID}-parks-prod
oc create -f ./Infrastructure/templates/cpd-parks-prod/mongodb_statefulset.yaml -n ${GUID}-parks-prod

oc expose svc/mongodb-internal -n ${GUID}-parks-prod
oc expose svc/mongodb -n ${GUID}-parks-prod

echo "Wait for dev project to create the imagestreams used in production"
sleep 10

# Create Blue/Green Applications
# MLB Parks
# Blue
oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=mlbparks-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc mlbparks-blue --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-blue --remove-all -n ${GUID}-parks-prod
# Green
oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=mlbparks-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc mlbparks-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod
oc expose dc mlbparks-green --port 8080 -n ${GUID}-parks-prod
oc create configmap mlbparks-config --from-literal="APPNAME=MLB Parks (Green)" -n ${GUID}-parks-prod

# National Parks
# Blue
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=nationalparks-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc nationalparks-blue --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc expose dc nationalparks-blue --port 8080 -n ${GUID}-parks-prod
oc create configmap nationalparks-blue-config --from-literal="APPNAME=National Parks (Blue)" -n ${GUID}-parks-prod
# Green
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=nationalparks-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc nationalparks-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod
oc expose dc nationalparks-green --port 8080 -n ${GUID}-parks-prod
oc create configmap nationalparks-green-config --from-literal="APPNAME=National Parks (Green)" -n ${GUID}-parks-prod

# ParksMap
# Blue
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=parksmap-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc parksmap-blue --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/parksmap-blue --remove-all -n ${GUID}-parks-prod
oc expose dc parksmap-blue --port 8080 -n ${GUID}-parks-prod
oc create configmap parksmap-blue-config --from-literal="APPNAME=ParksMap (Blue)" -n ${GUID}-parks-prod
# Green
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=parksmap-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc parksmap-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod
oc expose dc parksmap-green --port 8080 -n ${GUID}-parks-prod
oc create configmap parksmap-green-config --from-literal="APPNAME=ParksMap (Green)" -n ${GUID}-parks-prod

# set environmental variables for connecting to the db
oc set env dc/mlbparks-green DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/mlbparks-green-config -n ${GUID}-parks-prod
oc set env dc/mlbparks-blue DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/mlbparks-blue-config -n ${GUID}-parks-prod
oc set env dc/nationalparks-green DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/nationalparks-green-config -n ${GUID}-parks-prod
oc set env dc/nationalparks-blue DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/nationalparks-blue-config -n ${GUID}-parks-prod
oc set env dc/parksmap-green --from=configmap/parksmap-green-config -n ${GUID}-parks-prod
oc set env dc/parksmap-blue --from=configmap/parksmap-blue-config -n ${GUID}-parks-prod

# expose Green service as route 
oc expose svc/parksmap-green --name parksmap -n ${GUID}-parks-prod
oc expose svc/mlbparks-green --name mlbparks -n ${GUID}-parks-prod
oc expose svc/nationalparks-green --name nationalparks -n ${GUID}-parks-prod
