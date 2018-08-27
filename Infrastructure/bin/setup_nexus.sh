#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Process template 



# Setup template 



# Wait for Nexus to fully deploy and become ready
while : ; do
  echo "Checking if Nexus is Ready..."
  #oc get pod -n ${GUID}-nexus | grep -v deploy | grep "1/1"
  curl -i http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus) 2>&1 /dev/null | grep 'HTTP/1.1 200 OK' > /dev/null
  [[ "$?" == "1" ]] || break
  echo "... not quite yet. Sleeping 20 seconds."
  sleep 20
done

# Setup Nexus Repos
./Infrastructure/bin/configure_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus)

