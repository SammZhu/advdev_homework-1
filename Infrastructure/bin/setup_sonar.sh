#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"

# configure user access 
oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-sonarqube
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-sonarqube

# create new sonar app 
oc new-app --template=postgresql-persistent --param POSTGRESQL_USER=sonar --param POSTGRESQL_PASSWORD=sonar --param POSTGRESQL_DATABASE=sonar --param VOLUME_CAPACITY=4Gi --labels=app=sonarqube_db -n $GUID-sonarqube
oc new-app --docker-image=wkulhanek/sonarqube:6.7.4 --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube -n $GUID-sonarqube

# pause auto deployment
oc rollout pause dc sonarqube -n $GUID-sonarqube

# expose service 
oc expose service sonarqube -n $GUID-sonarqube

# create pvc
oc create -f ./Infrastructure/templates/cpd-sonarqube/sonarqube_pvc.yaml -n $GUID-sonarqube

# bind to pvc
oc set volume dc/sonarqube --add --overwrite --name=sonarqube-volume-1 --mount-path=/opt/sonarqube/data/ --type persistentVolumeClaim --claim-name=sonarqube-pvc -n $GUID-sonarqube

# update resources
oc set resources dc/sonarqube --limits=memory=3Gi,cpu=2 --requests=memory=2Gi,cpu=1 -n $GUID-sonarqube
oc patch dc sonarqube --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n $GUID-sonarqube

# add probes
oc set probe dc/sonarqube -n $GUID-sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/sonarqube -n $GUID-sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:9000/about

# rollout deployment 
oc rollout resume dc sonarqube -n $GUID-sonarqube