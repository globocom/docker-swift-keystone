#!/bin/sh

# Validate environment variables

# Example values:
#
# - KS_TENANT_NAME="gcom"
# - KS_USER_NAME="gcom-user"
# - KS_USER_PASSWORD="gcom-password"
# - KS_USER_EMAIL="appdev@corp.globo.com"
# - KS_SWIFT_PUBLIC_URL="http://s3.local.globoi.com:8080"
# - KS_SWIFT_INTERNAL_URL="http://s3.local.globoi.com:8080"
# - KS_SWIFT_ADMIN_URL="http://s3.local.globoi.com:8080"
# - KS_ADMIN_URL="http://auth.s3.local.globoi.com:35357"
#

if [ -z "${KS_TENANT_NAME}" ]; then
    echo "Environment variable KS_TENANT_NAME is not defined."
    echo "Setting default ..."
    KS_TENANT_NAME="gcom"
fi

if [ -z "${KS_USER_NAME}" ]; then
    echo "Environment variable KS_USER_NAME is not defined."
    echo "Setting default ..."
    KS_USER_NAME="gcom-user"
fi

if [ -z "${KS_USER_PASSWORD}" ]; then
    echo "Environment variable KS_USER_PASSWORD is not defined."
    echo "Setting default ..."
    KS_USER_PASSWORD="gcom-password"
fi

if [ -z "${KS_USER_EMAIL}" ]; then
    echo "Environment variable KS_USER_EMAIL is not defined."
    echo "Setting default ..."
    KS_USER_EMAIL="appdev@corp.globo.com"
fi

if [ -z "${KS_SWIFT_PUBLIC_URL}" ]; then
    echo "Environment variable KS_SWIFT_PUBLIC_URL is not defined."
    exit 1
fi

if [ -z "${KS_SWIFT_INTERNAL_URL}" ]; then
    echo "Environment variable KS_SWIFT_INTERNAL_URL is not defined."
    exit 1
fi

if [ -z "${KS_SWIFT_ADMIN_URL}" ]; then
    echo "Environment variable KS_SWIFT_ADMIN_URL is not defined."
    exit 1
fi

if [ -z "${KS_ADMIN_URL}" ]; then
    echo "Environment variable KS_ADMIN_URL is not defined."
    exit 1
fi

# Check keystone service

INTERVAL=5
MAX_ATTEMPTS=10
CHECK_COMMAND="curl -sL -w "%{http_code}" ${KS_ADMIN_URL} -o /dev/null"
ATTEMPTS=1
HTTP_RET_CODE=`${CHECK_COMMAND}`
while [ "000" = "${HTTP_RET_CODE}" ] && [ ${ATTEMPTS} -le ${MAX_ATTEMPTS} ]; do 
    echo "Error connecting to keystone. Attempt ${ATTEMPTS}. Retrying in ${INTERVAL} seconds ..."
    sleep ${INTERVAL}
    ATTEMPTS=$((ATTEMPTS+1))
    HTTP_RET_CODE=`${CHECK_COMMAND}`
done

if [ "000" = "${HTTP_RET_CODE}" ]; then
        echo "Error connecting to keystone. Aborting ..."
        exit 2
fi

# Create tenant

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"tenant\":{\"name\":\"${KS_TENANT_NAME}\",\"description\":\"default tenant\",\"enabled\":true}}" \
    ${KS_ADMIN_URL}/v2.0/tenants

TENANT_ID=`curl -s -H "X-Auth-Token:7a04a385b907caca141f" ${KS_ADMIN_URL}/v2.0/tenants | jq --arg v ${KS_TENANT_NAME} '.tenants[] | select(.name == $v).id'`
TENANT_ID="${TENANT_ID%\"}" ; TENANT_ID="${TENANT_ID#\"}"

# Create user

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"user\":{\"name\":\"${KS_USER_NAME}\",\"email\":\"${KS_USER_EMAIL}\",\"enabled\":true,\"password\":\"${KS_USER_PASSWORD}\",\"tenantId\":\"$TENANT_ID\"}}" \
    ${KS_ADMIN_URL}/v2.0/users

USER_ID=`curl -s -H "X-Auth-Token:7a04a385b907caca141f" ${KS_ADMIN_URL}/v2.0/users | jq --arg v ${KS_USER_NAME} '.users[] | select(.name == $v).id'`
USER_ID="${USER_ID%\"}" ; USER_ID="${USER_ID#\"}"

# Create admin role

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"role\":{\"name\":\"admin\"}}" \
    ${KS_ADMIN_URL}/v2.0/OS-KSADM/roles

OSKSADM_ID=`curl -s -H "X-Auth-Token:7a04a385b907caca141f" ${KS_ADMIN_URL}/v2.0/OS-KSADM/roles | jq '.roles[] | select(.name == "admin").id'`
OSKSADM_ID="${OSKSADM_ID%\"}" ; OSKSADM_ID="${OSKSADM_ID#\"}"

# Associate role to user

curl -s -X PUT \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    ${KS_ADMIN_URL}/v2.0/tenants/$TENANT_ID/users/$USER_ID/roles/OS-KSADM/$OSKSADM_ID

# Create Keystone service

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"OS-KSADM:service\":{\"name\":\"keystone\",\"type\":\"identity\",\"description\":\"Keystone Service\"}}" \
    ${KS_ADMIN_URL}/v2.0/OS-KSADM/services

SERVICE_KEYSTONE_ID=`curl -s -H "X-Auth-Token:7a04a385b907caca141f" ${KS_ADMIN_URL}/v2.0/OS-KSADM/services | jq '.["OS-KSADM:services"][] | select(.name=="keystone").id'`
SERVICE_KEYSTONE_ID="${SERVICE_KEYSTONE_ID%\"}" ; SERVICE_KEYSTONE_ID="${SERVICE_KEYSTONE_ID#\"}"

# Create Keystone endpoint

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"endpoint\":{\"region\":\"RegionOne\",\"service_id\":\"$SERVICE_KEYSTONE_ID\",\"publicurl\":\"${KS_ADMIN_URL}/v2.0\",\"adminurl\":\"${KS_ADMIN_URL}/v2.0\",\"internalurl\":\"${KS_ADMIN_URL}/v2.0\"}}" \
    ${KS_ADMIN_URL}/v2.0/endpoints

# Create Swift service

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"OS-KSADM:service\":{\"name\":\"swift\",\"type\":\"object-store\",\"description\":\"Swift Service\"}}" \
    ${KS_ADMIN_URL}/v2.0/OS-KSADM/services

SERVICE_ID=`curl -s -H "X-Auth-Token:7a04a385b907caca141f" ${KS_ADMIN_URL}/v2.0/OS-KSADM/services | jq '.["OS-KSADM:services"][] | select(.name=="swift").id'`
SERVICE_ID="${SERVICE_ID%\"}" ; SERVICE_ID="${SERVICE_ID#\"}"

# Create Swift endpoint

curl -s -X POST \
    -H "X-Auth-Token:7a04a385b907caca141f" \
    -H "Content-type: application/json" \
    -d "{\"endpoint\":{\"region\":\"RegionOne\",\"service_id\":\"${SERVICE_ID}\",\"publicurl\":\"${KS_SWIFT_PUBLIC_URL}/v1/AUTH_%(tenant_id)s\",\"adminurl\":\"${KS_SWIFT_ADMIN_URL}/v1/AUTH_%(tenant_id)s\",\"internalurl\":\"${KS_SWIFT_INTERNAL_URL}/v1/AUTH_%(tenant_id)s\"}}" \
    ${KS_ADMIN_URL}/v2.0/endpoints

# Replacing wildcards in proxy-server.conf for environment values

PROXY_CONF="/etc/swift/proxy-server.conf"
PROXY_CONF_TMP="/etc/swift/proxy-server.conf.tmp"
SED_TENANT_NAME="sed "s/KS_TENANT_NAME_VALUE/${KS_TENANT_NAME}/g""
SED_USER_NAME="sed "s/KS_USER_NAME_VALUE/${KS_USER_NAME}/g""
SED_USER_PASSWORD="sed "s/KS_USER_PASSWORD_VALUE/${KS_USER_PASSWORD}/g""
SED_ADMIN_URL="sed "s,KS_ADMIN_URL_VALUE,${KS_ADMIN_URL}/v3,g""
cat ${PROXY_CONF} | while read line
do
  echo $line | ${SED_ADMIN_URL} | ${SED_TENANT_NAME} | ${SED_USER_NAME} | ${SED_USER_PASSWORD} >> ${PROXY_CONF_TMP}
done
cat ${PROXY_CONF_TMP} > ${PROXY_CONF}
rm -f ${PROXY_CONF_TMP}

# Executing main script from container morrisjobke/docker-swift-onlyone

/usr/local/bin/startmain.sh


