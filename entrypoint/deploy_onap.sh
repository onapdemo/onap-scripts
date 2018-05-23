#!/bin/bash
usage() {
  cat <<EOF
Usage: $0 [PARAMs]
example 
./deploy_onap.sh -b amsterdam -e onap -t single (will rerun onap in the onap namespace, no new repo, no deletion of existing repo, deployment on single vm)
./deploy_onap.sh -b amsterdam -e onap -t cluster (will rerun onap in the onap namespace, no new repo, no deletion of existing repo, deployment on k8s cluster)
./deploy_onap.sh -b amsterdam -e onap -c true -d true ( new oom, delete prev oom)

-u                  : Display usage
-b [branch]         : branch = master or amsterdam (required)
-e [environment]    : use the default (onap)
-c [true|false]     : FLAG clone new oom repo (default: true)
-d [true|false]     : FLAG delete prev oom - (cd build) (default: false)
-t [type]           : type = single or cluster (required)
-r [true|false]     : FLAG deploy rancher and kubernetes on vm (default: false)
-n [dns name]       : Public ip of vm 
EOF
}

deploy_oom()
{

    if [[ "$TYPE_OF_VM" != "cluster" ]] && [[ "$DEPLOY_RANCHER" != false ]]; then
       sudo chmod 777 oom_rancher_setup.sh
      ./oom_rancher_setup.sh -b $BRANCH -s $DNS_NAME -e $ENVIRON	 
    fi	  

	if [[ "$DELETE_PREV_OOM" != false ]]; then
      echo "remove existing oom"
      source oom/kubernetes/oneclick/setenv.bash

      # master/beijing only - not amsterdam
      if [ "$BRANCH" == "master" ]; then
        oom/kubernetes/oneclick/deleteAll.bash -n $ENVIRON -y
      else
        oom/kubernetes/oneclick/deleteAll.bash -n $ENVIRON
      fi

      sleep 1
      # verify
      DELETED=$(kubectl get pods --all-namespaces -a | grep 0/ | wc -l)
      echo "verify deletion is finished."
      while [  $(kubectl get pods --all-namespaces | grep 0/ | wc -l) -gt 0 ]; do
        sleep 15
        echo "waiting for deletions to complete"
      done
    
      helm delete --purge onap-config
      # wait for 0/1 before deleting
      echo "sleeping 1 min"
      sleep 30

      echo " deleting /dockerdata-nfs"
      sudo chmod -R 777 /dockerdata-nfs/onap
      rm -rf /dockerdata-nfs/onap
      rm -rf oom
    fi


    if [[ "$CLONE_NEW_OOM" != false ]]; then 
      rm -rf oom
      echo "pull new oom"
	  docker pull elhaydox/oom:azure
	  docker run --rm -it -v $PWD:/test/ elhaydox/oom:azure
	  apt install zip -y
      unzip oom.zip -d oom
	 
      echo "start config pod"
      source oom/kubernetes/oneclick/setenv.bash
      cd oom/kubernetes/config
	  mv onap-parameters.yaml onap-parameters-orig.yaml 
      cp onap-parameters-sample.yaml onap-parameters.yaml 
      ./createConfig.sh -n $ENVIRON
      cd ../../../

      echo "verify onap-config is 0/1 not 1/1 - as in completed - an error pod - means you are missing onap-parameters.yaml or values are not set in it."
      while [  $(kubectl get pods -n $ENVIRON -a | grep config | grep 0/1 | grep Completed | wc -l) -eq 0 ]; do
        sleep 15
        echo "waiting for config pod to complete for ${ENVIRON}"
      done
    fi
    echo "start onap pods"
    source oom/kubernetes/oneclick/setenv.bash
    cd oom/kubernetes/oneclick
    if [[ "$TYPE_OF_VM" != "cluster" ]]; then
      ./createAll.bash -n $ENVIRON
    else
      echo "aaiServiceClusterIp: 10.96.255.254" > globalValues.yaml
      ./createAll.bash -n $ENVIRON -v globalValues.yaml
    fi

}

BRANCH=
ENVIRON=onap
DELETE_PREV_OOM=false
CLONE_NEW_OOM=true
TYPE_OF_VM=
DEPLOY_RANCHER=false
DNS_NAME=

while getopts ":u:b:e:c:d:t:r:n:" PARAM; do
  case $PARAM in
    u)
      usage
      exit 1
      ;;
    b)
      BRANCH=${OPTARG}
      ;;
    e)
      ENVIRON=${OPTARG}
      ;;
    c)
      CLONE_NEW_OOM=${OPTARG}
      ;;
    d)
      DELETE_PREV_OOM=${OPTARG}
      ;;
    t)
      TYPE_OF_VM=${OPTARG}
      ;;
	r)
	  DEPLOY_RANCHER=${OPTARG}
	  ;;
	n)
	  DNS_NAME=${OPTARG}
	  ;;
    ?)
      usage
      exit
      ;;
  esac
done

if [[ -z $BRANCH ]]; then
  usage
  exit 1
fi
if [[ -z $TYPE_OF_VM ]]; then
  usage
  exit 1
fi
if [[ -z $DNS_NAME ]]; then
  usage
  exit 1
fi

deploy_oom $BRANCH $ENVIRON $CLONE_NEW_OOM $DELETE_PREV_OOM $TYPE_OF_VM $DEPLOY_RANCHER $DNS_NAME

printf "**** Done ****\n"
