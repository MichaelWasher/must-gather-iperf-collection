# iPerf inter-Node test - Must-Gather image

This repository is used to build an image for use with the OpenShift Must-Gather tool.
The image will deploy a numbr of DaemonSets and other objects within the cluster to perform an iPerf test between appropriately tagged Nodes. 

# How to Use
iPerf inter-Node test tool is split into two parts, deploying and collecting. Once deployed, the iPerf Pods will automatically start and continue performing an iPerf test.

## Deploying


Before deploying the iPerf test, 2 Nodes should be singled for the test and labeled appropriately. 

NOTE: THIS DOES NOT SUPPORT ARBIRTRARY NUMBERS OF NODES IN A MESH. THERE CAN ONLY BE ONE SERVER AND ONE CLIENT.

Adding the `iperf-server=""` label to the desired Node will deploy an iPerf3 server on this Node in the host network-namespace.
Adding the `iperf-client=""` label to the desired Node will deploy an iPerf3 client on this Node in the host network-namespace and initiate a test with the Server.

```
$ oc label nodes/worker-0.mwasherovn.lab.upshift.rdu2.redhat.com iperf-server=""
$ oc label nodes/master-0.mwasherovn.lab.upshift.rdu2.redhat.com iperf-client=""
```

To start performing a test between Nodes using iPerf, the 'deploy' option is used when running the image as below:
```
$ oc adm must-gather --image=quay.io/mwasher/must-gather-iperf-collection -- deploy
```

## Collecting the iPerf results
To bundle and download the iPerf results from all labeled Nodes, the 'collect' option should be used as below:
```bash 
$ oc adm must-gather --image=quay.io/mwasher/must-gather-iperf-collection -- collect
```

# Uninstall
To remove the pcap collectors the 'destroy' option should be used:
```bash 
$ oc adm must-gather --image=quay.io/mwasher/must-gather-iperf-collection -- destroy
```
