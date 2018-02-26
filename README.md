# docker-swift-keystone
Docker for Swift and Keystone. (each app on a docker container started by docker-compose)

This project aims to provide a swift docker image with a custom configuration for keystone authorization system.
The docker-compose file shows how to use this swift image with the keystone image named garland/docker-openstack-keystone.

Environment variables wich can be replaced by user's values:

- KS_TENANT_NAME="gcom" (optional)
- KS_USER_NAME="gcom-user" (optional)
- KS_USER_PASSWORD="gcom-password" (optional)
- KS_USER_EMAIL="appdev@corp.com" (optional)
- KS_SWIFT_PUBLIC_URL="http://s3.local.com:8080"
- KS_SWIFT_INTERNAL_URL="http://s3.local.com:8080"
- KS_SWIFT_ADMIN_URL="http://s3.local.com:8080"
- KS_ADMIN_URL="http://auth.s3.local.com:35357"
