#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Create a Jenkins instance with persistent storage and sufficient resources
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=4Gi --param VOLUME_CAPACITY=4Gi -n ${GUID}-jenkins

# Allow Jenkins service account to access the dev and prod projects 
oc policy add-role-to-user edit system:serviceaccount:cpd-jenkins:jenkins -n ${GUID}-parks-dev
oc policy add-role-to-user edit system:serviceaccount:cpd-jenkins:jenkins -n ${GUID}-parks-prod

# Adjust readiness probe for Jenkins
oc set probe dc jenkins --readiness --initial-delay-seconds=1200 -n ${GUID}-jenkins

# Setup Jenkins Maven ImageStream for Jenkins slave builds
oc new-build --name=maven-slave-pod -D $'FROM openshift/jenkins-slave-maven-centos7:v3.9\nUSER root\nRUN yum -y install skopeo apb && yum clean all\nUSER 1001' -n ${GUID}-jenkins

# Sleep 30 seconds for Image Stream to be created
sleep 30

# Wait for Jenkins to deploy and become ready
while : ; do
  echo "Checking if Jenkins is Ready..."
  oc get pod -n ${GUID}-jenkins | grep -v "deploy\|build" | grep -q "1/1"
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done

# Add version 3.9 tag to Jenkins slave ImageStream
oc tag maven-slave-pod:latest maven-slave-pod:v3.9 -n ${GUID}-jenkins

# Create pipeline build configurations for each application
oc create -f ./Infrastructure/templates/cpd-jenkins/mlbparks-pipeline.yaml -n ${GUID}-jenkins
oc create -f ./Infrastructure/templates/cpd-jenkins/nationalparks-pipeline.yaml -n ${GUID}-jenkins
oc create -f ./Infrastructure/templates/cpd-jenkins/parksmap-pipeline.yaml -n ${GUID}-jenkins

# set environmental variables in build configs for pipeline: GUID, Cluster
oc set env bc/mlbparks-pipeline GUID=${GUID} REPO=${REPO} CLUSTER=${CLUSTER} -n ${GUID}-jenkins
oc set env bc/nationalparks-pipeline GUID=${GUID} REPO=${REPO} CLUSTER=${CLUSTER} -n ${GUID}-jenkins
oc set env bc/parksmap-pipeline GUID=${GUID} REPO=${REPO} CLUSTER=${CLUSTER} -n ${GUID}-jenkins
