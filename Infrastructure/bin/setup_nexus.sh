#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Allow Jenkins service account to edit and delete the project

oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n ${GUID}-nexus

# Setup Nexus
oc new-app sonatype/nexus3:latest
oc expose svc nexus3
oc rollout pause dc nexus3
oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
oc set resources dc nexus3 --limits=memory=2Gi --requests=memory=1Gi

# Setup pvc
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -

# mount pvc
oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc

# configure probes
oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/

# add port for docker
oc patch dc nexus3 -p '{"spec":{"template":{"spec":{"containers":[{"name":"nexus3","ports":[{"containerPort": 5000,"protocol":"TCP","name":"docker"}]}]}}}}'

# continue rollout 
oc rollout resume dc nexus3

# expose service port 
oc expose dc nexus3 --port=5000 --name=nexus-registry

# expose route port
oc create route edge nexus-registry --service=nexus-registry --port=5000

# Wait for Nexus to fully deploy and become ready
while : ; do
  echo "Checking if Nexus is Ready..."
  #oc get pod -n ${GUID}-nexus | grep -v deploy | grep "1/1"
  curl -i http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus) 2>&1 /dev/null | grep 'HTTP/1.1 200 OK' > /dev/null
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done

# Configure nexus to be a docker repository
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 -n ${GUID}-nexus --template='{{ .spec.host }}')
rm setup_nexus3.sh