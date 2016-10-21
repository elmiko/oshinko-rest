#!/bin/bash

# This script is for deploying oshinko into OpenShift. The target of
# installation can be an existing OpenShift deployment or an all-in-one
# container can be started.
#
# In either case, access to the `oc` command is required.
#
# example usage:
#
#    $ oshinko-deploy.sh -c 10.0.1.100 -o oshinko.10.0.1.100.xip.io
#
# this will deploy oshinko into the OpenShift cluster running at 10.0.1.100
# and set the oshinko webui route url to oshinko.10.0.1.100.xip.io.
# further it will use the user `developer` and project `myproject`, asking
# for a login when appropriate.
# for further parameters please see the help text.

if which oc &> /dev/null
then :
else
    echo "Cannot find oc command, please check path to ensure it is installed"
    exit 1
fi

DEFAULT_OSHINKO_REST_IMAGE=radanalyticsio/oshinko-rest
DEFAULT_OSHINKO_WEB_IMAGE=radanalyticsio/oshinko-webui
DEFAULT_SPARK_IMAGE=radanalyticsio/openshift-spark
DEFAULT_OPENSHIFT_USER=developer
DEFAULT_OPENSHIFT_PROJECT=myproject

while getopts :dc:u:p:s:w:r:o:h opt; do
    case $opt in
        d)
            OS_ALLINONE=true
            ;;
        c)
            OS_CLUSTER=$OPTARG
            ;;
        u)
            OS_USER=$OPTARG
            USER_REQUESTED=true
            ;;
        p)
            PROJECT=$OPTARG
            ;;

        s)
            SPARK_IMAGE=$OPTARG
            ;;
        w)
            WEB_IMAGE=$OPTARG
            ;;
        r)
            REST_IMAGE=$OPTARG
            ;;
        o)
            WEBROUTE=$OPTARG
            ;;
        h)
            echo "usage: oshinko-deploy.sh [options]"
            echo
            echo "deploy the oshinko suite into a running OpenShift cluster"
            echo
            echo "optional arguments:"
            echo "  -h            show this help message"
            echo "  -d            create an all-in-one docker OpenShift on localhost"
            echo "  -c CLUSTER    OpenShift cluster url to login against (default: https://localhost:8443)"
            echo "  -u USER       OpenShift user to run commands as (default: $DEFAULT_OPENSHIFT_PROJECT)"
            echo "  -p PROJECT    OpenShift project name to install oshinko into (default: $DEFAULT_OPENSHIFT_USER)"
            echo "  -s IMAGE      spark docker image to use for clusters (default: $DEFAULT_SPARK_IMAGE)"
            echo "  -w IMAGE      oshinko-webui docker image to use for deployment (default: $DEFAULT_OSHINKO_WEB_IMAGE)"
            echo "  -r IMAGE      oshinko-webui docker image to use for deployment (default: $DEFAULT_OSHINKO_WEB_IMAGE)"
            echo "  -o HOSTNAME   hostname to use in exposed route to oshinko-web"
            echo
            exit
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit
            ;;
    esac
done

if [ -z "$OS_USER" ]
then
    echo "user not set, using default value"
    OS_USER=$DEFAULT_OPENSHIFT_USER
fi

if [ -z "$PROJECT" ]
then
    echo "project name not set, using default value"
    PROJECT=$DEFAULT_OPENSHIFT_PROJECT
fi

if [ -z "$SPARK_IMAGE" ]
then
    SPARK_IMAGE=$DEFAULT_SPARK_IMAGE
fi

if [ -z "$WEB_IMAGE" ]
then
    WEB_IMAGE=$DEFAULT_OSHINKO_WEB_IMAGE
fi

if [ -z "$REST_IMAGE" ]
then
    REST_IMAGE=$DEFAULT_OSHINKO_REST_IMAGE
fi

if [ -n "$OS_ALLINONE" ]
then
    if [ -n "$OS_CLUSTER" ]
    then
        echo "Error: You have requested an all-in-one deployment AND specified a cluster address."
        echo "Please choose one of these options and restart."
        exit 1
    fi
    if [ -n "$USER_REQUESTED" ]
    then
        echo "Error: You have requested an all-in-one deployment AND specified an OpenShift user."
        echo "Please choose either all-in-one or a cluster deployment if you need to use a specific user."
        exit 1
    fi
    oc cluster up
fi

oc login $OS_CLUSTER -u $OS_USER

oc new-project $PROJECT

oc create sa oshinko -n $PROJECT
oc policy add-role-to-user admin system:serviceaccount:$PROJECT:oshinko -n $PROJECT

curl -s \
    https://raw.githubusercontent.com/radanalyticsio/oshinko-rest/master/tools/server-ui-template.yaml \
  | oc create -n $PROJECT -f -

if [ -n "$WEBROUTE" ]
then
oc new-app --template oshinko \
           -n $PROJECT \
           -p OSHINKO_SERVER_IMAGE=$REST_IMAGE \
           -p OSHINKO_CLUSTER_IMAGE=$SPARK_IMAGE \
           -p OSHINKO_WEB_IMAGE=$WEB_IMAGE \
           -p OSHINKO_WEB_ROUTE_HOSTNAME=$WEBROUTE
else
oc new-app --template oshinko \
           -n $PROJECT \
           -p OSHINKO_SERVER_IMAGE=$REST_IMAGE \
           -p OSHINKO_CLUSTER_IMAGE=$SPARK_IMAGE \
           -p OSHINKO_WEB_IMAGE=$WEB_IMAGE
fi