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

# Create Jenkins objects from templates
oc create -f project.yaml -n ${GUID}-jenkins
oc create -f serviceaccounts.yaml -n ${GUID}-jenkins
oc create -f pvc.yaml -n ${GUID}-jenkins
oc create -f rolebindings.yaml -n ${GUID}-jenkins

# Create the maven slave pod 
oc new-build --name=maven-slave-pod \
    --dockerfile="$(< ./Infrastructure/templates/jenkins/Dockerfile)" \
    -n $GUID-jenkins

# Set latest tag 
oc tag jenkins-slave-maven-skopeo-centos7 jenkins-slave-maven-skopeo-centos7:latest -n ${GUID}-jenkins

# Wait for Jenkins to deploy and become ready
while : ; do
  echo "Checking if Jenkins pod is Ready..."
  oc get pod -n ${GUID}-jenkins | grep -v "deploy\|build" | grep -q "1/1"
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done



# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student
