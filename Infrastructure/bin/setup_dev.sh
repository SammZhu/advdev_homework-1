#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# configure user access  
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-dev
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-dev

# allow gading pipeline to edit + delete projects
oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-dev
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-parks-dev

oc new-app -f ./Infrastructure/templates/cpd-parks-dev/mongodb_services.yaml -n ${GUID}-parks-dev
oc create -f ./Infrastructure/templates/cpd-parks-dev/mongodb_statefulset.yaml -n ${GUID}-parks-dev

oc expose svc/mongodb-internal -n ${GUID}-parks-dev
oc expose svc/mongodb -n ${GUID}-parks-dev

# set up binary builds ready to use the war files built from the pipeline
oc new-build --binary=true --name=${ParksMap} redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev
oc new-build --binary=true --name=${MlbParks} jboss-eap70-openshift:1.6 -n ${GUID}-parks-dev
oc new-build --binary=true --name=${NationalParks} redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev

# set up config maps for each micro-service
oc create configmap ${ParksMap}-config --from-literal="APPNAME=ParksMap (Dev)" -n ${GUID}-parks-dev
oc create configmap ${MlbParks}-config --from-literal="APPNAME=MLB Parks (Dev)" -n ${GUID}-parks-dev
oc create configmap ${NationalParks}-config --from-literal="APPNAME=National Parks (Dev)" -n ${GUID}-parks-dev

# set up placeholder deployments
oc new-app ${GUID}-parks-dev/${ParksMap}:0.0-0 --name=${ParksMap} --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/${MlbParks}:0.0-0 --name=${MlbParks} --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/${NationalParks}:0.0-0 --name=${NationalParks} --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev

# set environmental variables for connecting to mongo db
oc set env dc/${MlbParks} DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/${MlbParks}-config -n ${GUID}-parks-dev
oc set env dc/${NationalParks} DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/${NationalParks}-config -n ${GUID}-parks-dev
oc set env dc/${ParksMap} --from=configmap/${ParksMap}-config -n ${GUID}-parks-dev

# set up deployment hooks so the backend services can be populated
oc set triggers dc/${ParksMap} --remove-all -n ${GUID}-parks-dev
oc set triggers dc/${MlbParks} --remove-all -n ${GUID}-parks-dev
oc set triggers dc/${NationalParks} --remove-all -n ${GUID}-parks-dev

# set up health probes
oc set probe dc/${ParksMap} -n ${GUID}-parks-dev --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/${ParksMap} --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set probe dc/${MlbParks} -n ${GUID}-parks-dev --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/${MlbParks} --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set probe dc/${NationalParks} -n ${GUID}-parks-dev --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/${NationalParks} --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

# expose and label the services so the front end (${ParksMap}) can find them
oc expose dc ${ParksMap} --port 8080 -n ${GUID}-parks-dev
oc expose svc ${ParksMap} -n ${GUID}-parks-dev

oc expose dc ${MlbParks} --port 8080 -n ${GUID}-parks-dev
oc expose svc ${MlbParks} --labels="type=parksmap-backend" -n ${GUID}-parks-dev

oc expose dc ${NationalParks} --port 8080 -n ${GUID}-parks-dev
oc expose svc ${NationalParks} --labels="type=parksmap-backend" -n ${GUID}-parks-dev
