#!/bin/bash
# Setup PRODUCTION Project
if [ "$#" -ne 4 ]; then
    echo "Usage:"
    echo "  $0 PROD_NAMESPACE TOOLS_NAMESPACE APP_NAME ENV [QA, SIT, UAT, PRE-PROD, PROD]"
    exit 1
fi

PROD_NAMESPACE=$1
TOOLS_NAMESPACE=$2
APP_NAME=$3
ENV=$4
echo "Setting up RH PAM PRODUCTION Environment in project ${PROD_NAMESPACE}"


echo "#################################################################################################"
echo " Create secrets for Business Central & KIE Servers based on pre-prepared keystores"
echo " Business Central keystore: ocp_pam_app_dev/Infrastructure/templates76/secrets/bckeystore.jks"
echo " Business Central keystore: ocp_pam_app_dev/Infrastructure/templates76/secrets/kiekeystore.jks"
echo "#################################################################################################"

oc create secret generic businesscentral-app-secret --from-file=./Infrastructure/templates76/secrets/bckeystore.jks -n ${PROD_NAMESPACE}
oc create secret generic kieserver-app-secret --from-file=./Infrastructure/templates76/secrets/kiekeystore.jks -n ${PROD_NAMESPACE}

echo ""
echo ""
echo "#################################################################################################"
echo " Configure the settings.xml to be used to download RHPAM Artifacts proxied by nexus in tools namespace"
echo "#################################################################################################"
echo ""

#NEXUS_ROUTE_URL=http://$(oc get route nexus3 --template='{{ .spec.host }}' -n $TOOLS_NAMESPACE)
NEXUS_ROUTE_URL=http://$(oc get route nexus --template='{{ .spec.host }}' -n $TOOLS_NAMESPACE)
echo "NEXUS_ROUTE_URL=$NEXUS_ROUTE_URL"

# Add NEXUS URL 
sed -ie "s@URL@${NEXUS_ROUTE_URL}/repository/maven-all-public/@g" ./Infrastructure/templates76/settings.xml

echo "create configmap to contain location of the NEXUS mirror and repositories to be used by RHPAMCENTRAL and KIE SERVER for artifact downloads"
oc create configmap settings.xml --from-file ./Infrastructure/templates76/settings.xml

# Reset back to URL in case need to change for PROD
sed -ie "s@${NEXUS_ROUTE_URL}/repository/maven-all-public/@URL@g" ./Infrastructure/templates76/settings.xml

echo "Distribution management for RHPAM projects"
echo ""
echo "The setup utilizes RHPAM Central internal GIT Repo as source of truth (not recommended for final instalation)"
echo "The setup expects manual via RHPAM Central build and deployment of PAM Projects via distribution to the NEXUS server"
echo ""
echo "All new projects created in RHPAM Central will have to be modifed so that POM.XML contains the following sections"
echo ""
echo " <distributionManagement>"
echo "   <repository>"
echo "     <id>nexu</id>"
echo "     <url>${NEXUS_ROUTE_URL}/repository/maven-releases</url>"
echo "   </repository>"
echo "   <snapshotRepository>"
echo "     <id>nexu</id>"
echo "     <url>${NEXUS_ROUTE_URL}/repository/maven-snapshots</url>"
echo "   </snapshotRepository>"
echo " </distributionManagement>"

echo ""
echo ""
echo "#################################################################################################"
echo " Configure RHPAM & KIESERVER (managed, non clustered, hypersonic db) without RHSSO integration" 
echo ""
echo " RHPAM Login: rhpamadmin/rhpamadmin760 "
echo ""
echo " User management: for execution"
echo " 		- credentials: executionUser/executionUser123 roles: kie-server,rest-all,guest"
echo " Further users: "
echo "		- Step 1: Add to business central"
echo "		     oc rsh <rhpamcentral POD>"
echo "               cd /opt/eap/bin"
echo "               ./add-user.sh -a -u <user-name> -p <password> -g kie-server,rest-all,<YOUR ROLE from Business Process>,<analyst: if user to start process from business central>"
echo "		- Step 2: Add same user to kieserver"
echo "		     oc rsh <kieserver POD>"
echo "               cd /opt/eap/bin"
echo "               ./add-user.sh -a -u <user-name> -p <password> -g kie-server,rest-all,<YOUR ROLE from Business Process>"
echo "#################################################################################################"
echo ""
oc new-app --template=rhpam76-prod-managed  -p BUSINESS_CENTRAL_HTTPS_SECRET=businesscentral-app-secret -p KIE_SERVER_HTTPS_SECRET=kieserver-app-secret  \
-p APPLICATION_NAME=${APP_NAME} -p BUSINESS_CENTRAL_HTTPS_NAME=businesscentral  -p BUSINESS_CENTRAL_HTTPS_PASSWORD=mykeystorepass  -p BUSINESS_CENTRAL_HTTPS_KEYSTORE=bckeystore.jks  \
-p KIE_SERVER_HTTPS_NAME=kieserver  -p KIE_SERVER1_HOSTNAME_HTTP="${APP_NAME}-kieserver-cluster-group-1-${DEV_NAMESPACE}.${CLUSTER}" \
-p KIE_SERVER2_HOSTNAME_HTTP="${APP_NAME}-kieserver-cluster-group-2-${DEV_NAMESPACE}.${CLUSTER}" -p KIE_SERVER_HTTPS_PASSWORD=mykeystorepass   -p KIE_SERVER_HTTPS_KEYSTORE=kiekeystore.jks  \
-p KIE_ADMIN_USER=rhpamadmin   -p KIE_ADMIN_PWD=rhpamadmin760   -p KIE_SERVER_USER=executionUser   -p KIE_SERVER_PWD=executionUser123   -p KIE_SERVER_CONTROLLER_USER=controllerUser   \
-p KIE_SERVER_CONTROLLER_PWD=controllerUser123 -p MAVEN_REPO_URL=${NEXUS_ROUTE_URL}/maven-public  -p MAVEN_REPO_USERNAME=admin  -p MAVEN_REPO_PASSWORD=admin123  -p MAVEN_REPO_ID=maven-public \
-p SMART_ROUTER_CONTAINER_REPLICAS=1 -p KIE_SERVER_CONTAINER_REPLICAS=1 -l app=pam-${APP_NAME}-${ENV} -n ${PROD_NAMESPACE}

echo ""
echo ""
echo "#################################################################################################"
echo " Configure SSO for the apps"
echo " TODO	BUSINESS CENTRAL ... send JSON for ${APP_NAME}-rhpamcentral client creation - TYPE: confidentiality"
echo " TODO	BUSINESS CENTRAL ... send JSON for ${APP_NAME}-rhpamcentral client creation - TYPE: token bearer"
echo " TODO	curl ... send JSON for ${APP_NAME}-rhpamcentral client creation - TYPE: confidentiality"
echo "#################################################################################################"

echo ""
echo ""
echo "#################################################################################################"
echo " Configure RHPAM & KIESERVER (managed, non clustered, hypersonic db) with RHSSO integration" 
echo ""
echo " RHPAM Login: rhpamadmin/rhpamadmin760 "
echo ""
echo ""
echo " User management: for execution" 
echo " 		- initial credentials: executionUser/executionUser123 roles: kie-server,rest-all,guest"
echo ""
echo "          - example adding new user (JSON, REMOTE COMMAND, to realm and client with variable roles"
echo "#################################################################################################"
echo ""
SSO_ROUTE_URL=http://$(oc get route ${APP_NAME}-sso --template='{{ .spec.host }}' -n $TOOLS_NAMESPACE)

echo "URL to authenticate with SSO $SSO_ROUTE_URL/auth with ssoadmin/ssoadmin730!"
echo ""
echo "removed creation until RHSSO issue corrected"














