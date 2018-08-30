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

# To be Implemented by Student

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
oc new-app ${GUID}-parks-dev/${MlbParks}:0.0 --name=${MlbParks}-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc ${MlbParks}-blue --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/${MlbParks}-blue --remove-all -n ${GUID}-parks-prod
oc expose dc ${MlbParks}-blue --port 8080 -n ${GUID}-parks-prod
oc create configmap ${MlbParks}-blue-config --from-literal="APPNAME=MLB Parks (Blue)" -n ${GUID}-parks-prod
# Green
oc new-app ${GUID}-parks-dev/${MlbParks}:0.0 --name=${MlbParks}-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc ${MlbParks}-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/${MlbParks}-green --remove-all -n ${GUID}-parks-prod
oc expose dc ${MlbParks}-green --port 8080 -n ${GUID}-parks-prod
oc create configmap ${MlbParks}-green-config --from-literal="APPNAME=MLB Parks (Green)" -n ${GUID}-parks-prod

# National Parks
# Blue
oc new-app ${GUID}-parks-dev/${NationalParks}:0.0 --name=${NationalParks}-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc ${NationalParks}-blue --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/${NationalParks}-blue --remove-all -n ${GUID}-parks-prod
oc expose dc ${NationalParks}-blue --port 8080 -n ${GUID}-parks-prod
oc create configmap ${NationalParks}-blue-config --from-literal="APPNAME=National Parks (Blue)" -n ${GUID}-parks-prod
# Green
oc new-app ${GUID}-parks-dev/${NationalParks}:0.0 --name=${NationalParks}-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc ${NationalParks}-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/${NationalParks}-green --remove-all -n ${GUID}-parks-prod
oc expose dc ${NationalParks}-green --port 8080 -n ${GUID}-parks-prod
oc create configmap ${NationalParks}-green-config --from-literal="APPNAME=National Parks (Green)" -n ${GUID}-parks-prod

# ParksMap
# Blue
oc new-app ${GUID}-parks-dev/${ParksMap}:0.0 --name=${ParksMap}-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc ${ParksMap}-blue --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/${ParksMap}-blue --remove-all -n ${GUID}-parks-prod
oc expose dc ${ParksMap}-blue --port 8080 -n ${GUID}-parks-prod
oc create configmap ${ParksMap}-blue-config --from-literal="APPNAME=ParksMap (Blue)" -n ${GUID}-parks-prod
# Green
oc new-app ${GUID}-parks-dev/${ParksMap}:0.0 --name=${ParksMap}-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc patch dc ${ParksMap}-green --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-parks-prod
oc set triggers dc/${ParksMap}-green --remove-all -n ${GUID}-parks-prod
oc expose dc ${ParksMap}-green --port 8080 -n ${GUID}-parks-prod
oc create configmap ${ParksMap}-green-config --from-literal="APPNAME=ParksMap (Green)" -n ${GUID}-parks-prod

# set environmental variables for connecting to the db
oc set env dc/${MlbParks}-green DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/${MlbParks}-green-config -n ${GUID}-parks-prod
oc set env dc/${MlbParks}-blue DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/${MlbParks}-blue-config -n ${GUID}-parks-prod
oc set env dc/${NationalParks}-green DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/${NationalParks}-green-config -n ${GUID}-parks-prod
oc set env dc/${NationalParks}-blue DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/${NationalParks}-blue-config -n ${GUID}-parks-prod
oc set env dc/${ParksMap}-green --from=configmap/${ParksMap}-green-config -n ${GUID}-parks-prod
oc set env dc/${ParksMap}-blue --from=configmap/${ParksMap}-blue-config -n ${GUID}-parks-prod

# expose Green service as route to make blue application active
oc expose svc/${ParksMap}-green --name ${ParksMap} -n ${GUID}-parks-prod
oc expose svc/${MlbParks}-green --name ${MlbParks} -n ${GUID}-parks-prod
oc expose svc/${NationalParks}-green --name ${NationalParks} -n ${GUID}-parks-prod
