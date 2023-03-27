#!/bin/bash
set -euf -o pipefail

#Prerequistes
## OC is logged into cluster
## user can create namespaces and daemonsets.

#This script with run an iperf on each node betweent the client and server pod, then test between the nodes [if two nodes are set]

#Test 1
## node1 -> node1
## node2 -> node2

#Test 2
## node1 -> node2

# The idea is to check the performence of each nodes ovs/packet forwarding performence, and then test between nodes for a real world example also.

## variables ##
# udp / bitrate 10M / bitrate 100M / bitrate 1Gbit
# tcp / bitrate unlimited / inital windows size 1

#TEST SETTTINGS
set -x

TESTTIME=300

#IF TESTTIME = 300 and 2 nodes selected, each test case will take 15minutes.
TEST_CASES=(
""
"-u -b 1M"
"-u -b 10M"
"-u -b 100M"
"-u -b 250M"
"-u -b 500M"
)

function listnodes
{
    oc get nodes -o jsonpath='{range .items[*].metadata.labels}{.kubernetes\.io/hostname}{"\n"}'
}

function checknodename 
{
    echo checking node \"$1\" is valid
    if [ $(oc get nodes -l kubernetes.io/hostname="$1" -o name | wc -l ) -ne 1 ]
    then
        echo node name \"$1\" invalid below are valid names
        listnodes
        exit 1
    fi

}

function get_server_nodename
{
    echo `oc get  node -l iperf-server -o name | cut -f 2- -d "/"`
}

function get_client_nodename
{
    echo `oc get  node -l iperf-client -o name | cut -f 2- -d "/"`
}

#Pass node and get pod name of client pod
function getclientpod
{
  oc get -n "$NAMESPACE" pod -o name --field-selector=spec.nodeName="$1" -l iperf-client=""
}

#Pass node and get pod name of server pod
function getserverpod
{
  oc get -n "$NAMESPACE" pod -o name --field-selector=spec.nodeName="$1" -l iperf-server=""
}

CLIENT_NODE=$(get_client_nodename)
SERVER_NODE=$(get_server_nodename)
IPFAMILY=4

#TODO: check usage ^
RUNDIR=$(dirname $0)
NAMESPACE=iperf-collect

#wait for all the pods to be ready
echo "Waiting for all pods to be ready"
sleep 5 #Give DS time to make pods
oc get pods -n "$NAMESPACE" -o wide
echo ""
oc wait pods -n "$NAMESPACE" --all --for=condition=Ready  --timeout=60s


#pass pod/name and get pod ipaddr
function getpodip
{
  
  if [[ "$IPFAMILY" -eq 4 ]]
  then
    #IPV4
    oc get -n "$NAMESPACE" "$1" -o jsonpath="{.status.podIP}"
  else
    #IPv6
    #HACK: Terrible ipv6 filtering. but does the job
    oc get -n "$NAMESPACE" "$1" -o jsonpath='{range .status.podIPs[*]}{.ip}{"\n"}{end}' | egrep "([a-fA-F0-9]*:?)+(:[a-fA-F0-9]+)"
  fi
}

#create folder for test results
RUNNAME="iperf_$( date "+%s" )"
RESULTS="$RUNDIR/$RUNNAME"
echo Results stored in $RESULTS
mkdir -p "$RESULTS"

#Store some cluster info
oc get pods -n "$NAMESPACE" -o yaml > "$RESULTS/pods.yaml"
oc get Network.config.openshift.io cluster -o yaml > "$RESULTS/networkconfig.yaml"

#Run iperfs
function runiperf
{
  NODEA="$1"
  NODEB="$2"
  echo $NODEA
  echo $NODEB

  CPOD=$(getclientpod "$NODEA")
  SPOD=$(getserverpod "$NODEB")
  SPOD_IP=$(getpodip "$SPOD")
  CPOD_IP=$(getpodip "$CPOD")  
  echo $CPOD
  echo $SPOD
  
  for ((i = 0; i < ${#TEST_CASES[@]}; i++))
  do
    FLATARGS="$( tr '[:space:]' _ <<<${TEST_CASES[$i]} )"
    RESULTFILE="${NODEA}_${NODEB}_${FLATARGS}.json"
    echo TEST "$NODEA" to "$NODEB" ARGS: "${TEST_CASES[$i]}"
    set -x
    #when iperf3 runs in jsonmode it does not output anything untill compleate, this causes the exec commaned socket to get marked idle and killed.
    #We simply poll using bash and copy the results back.

    oc -n "$NAMESPACE" exec "$CPOD" -- iperf3 -J -c "$SPOD_IP" -t "$TESTTIME" --logfile "/tmp/$RESULTFILE" ${TEST_CASES[$i]}
    #wait for iperf is compleate
    oc -n "$NAMESPACE" exec -it "$CPOD" -- bash -c 'while [ "$( pgrep iperf3 | wc -l)" -eq 1 ] ; do echo -n .; sleep 5 ; done; echo finished'
    #Copy results back
    oc -n "$NAMESPACE" exec -it "$CPOD" -- cat "/tmp/$RESULTFILE" > "$RESULTS/$RESULTFILE"

    set +x
  done
 
}

runiperf "$CLIENT_NODE" "$SERVER_NODE"

echo "!!! Success !!!"
echo Results in "$RESULTS"
tar -cvf "$RESULTS.tar.gz" "$RESULTS"

echo "Please attach" "$RESULTS.tar.gz" "to your case"
