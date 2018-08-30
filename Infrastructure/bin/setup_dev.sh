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

oc new-app -f ../templates/cpd-parks-dev/mongodb_services.yaml -n ${GUID}-parks-dev
oc create -f ../templates/cpd-parks-dev/mongodb_statefulset.yaml -n ${GUID}-parks-dev

oc expose svc/mongodb-internal -n ${GUID}-parks-dev
oc expose svc/mongodb -n ${GUID}-parks-dev

# set up binary builds ready to use the war files built from the pipeline
oc new-build --binary=true --name=parksmap redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev
oc new-build --binary=true --name=mlbparks jboss-eap70-openshift:1.6 -n ${GUID}-parks-dev
oc new-build --binary=true --name=nationalparks redhat-openjdk18-openshift:1.2 -n ${GUID}-parks-dev

# set up config maps for each micro-service
oc create configmap parksmap-config --from-literal="APPNAME=ParksMap (Dev)" -n ${GUID}-parks-dev
oc create configmap mlbparks-config --from-literal="APPNAME=MLB Parks (Dev)" -n ${GUID}-parks-dev
oc create configmap nationalparks-config --from-literal="APPNAME=National Parks (Dev)" -n ${GUID}-parks-dev

# set up placeholder deployments
oc new-app ${GUID}-parks-dev/parksmap:0.0-0 --name=parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/mlbparks:0.0-0 --name=mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev
oc new-app ${GUID}-parks-dev/nationalparks:0.0-0 --name=nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-dev

# set environmental variables for connecting to mongodb
oc set env dc/mlbparks DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/mlbparks-config -n ${GUID}-parks-dev
oc set env dc/nationalparks DB_HOST=mongodb DB_PORT=27017 DB_USERNAME=mongodb DB_PASSWORD=mongodb DB_NAME=mongodb DB_REPLICASET=rs0 --from=configmap/nationalparks-config -n ${GUID}-parks-dev
oc set env dc/parksmap --from=configmap/parksmap-config -n ${GUID}-parks-dev

# set up deployment hooks so the backend services can be populated
oc set triggers dc/parksmap --remove-all -n ${GUID}-parks-dev
oc set triggers dc/mlbparks --remove-all -n ${GUID}-parks-dev
oc set triggers dc/nationalparks --remove-all -n ${GUID}-parks-dev

# set up health probes
oc set probe dc/parksmap -n ${GUID}-parks-dev --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/parksmap --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set probe dc/mlbparks -n ${GUID}-parks-dev --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/mlbparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

oc set probe dc/nationalparks -n ${GUID}-parks-dev --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/nationalparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-dev

# expose and label the services so the front end (parksmap) can find them
oc expose dc parksmap --port 8080 -n ${GUID}-parks-dev
oc expose svc parksmap -n ${GUID}-parks-dev

oc expose dc mlbparks --port 8080 -n ${GUID}-parks-dev
oc expose svc mlbparks --labels="type=parksmap-backend" -n ${GUID}-parks-dev

oc expose dc nationalparks --port 8080 -n ${GUID}-parks-dev
oc expose svc nationalparks --labels="type=parksmap-backend" -n ${GUID}-parks-dev
