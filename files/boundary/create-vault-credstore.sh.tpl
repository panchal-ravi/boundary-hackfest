#!/bin/bash

export BOUNDARY_ADDR=${boundary_cluster_url}
export AUTH_ID=$(boundary-worker auth-methods list -scope-id global -keyring-type=none  -format json | jq ".items[].id" -r)
export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=${boundary_password}
export BOUNDARY_TOKEN=$(boundary-worker authenticate password -auth-method-id=$AUTH_ID -keyring-type=none  -login-name=admin -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD -format json | jq .item.attributes.token -r)
export ORG_ID=$(boundary-worker scopes list -scope-id global -keyring-type=none -token env://BOUNDARY_TOKEN -recursive -format json | jq '.items[] | select(.scope.type=="global") | .id' -r)
export PROJECT_ID=$(boundary-worker scopes list -scope-id global  -keyring-type=none -token env://BOUNDARY_TOKEN -recursive -format json | jq '.items[] | select(.scope.type=="org") | .id' -r)

boundary-worker credential-stores create vault \
    -keyring-type=none \
    -token env://BOUNDARY_TOKEN \
    -vault-address "http://${vault_ip}:8200" \
    -vault-token "${boundary_token}" \
    -worker-filter "\"ingress\" in \"/tags/type\"" \
    -scope-id $PROJECT_ID \
    -name vault-cred-store \
    -description "Vault credential store" -format json | jq ".item.id" -r > /home/ubuntu/vault_credstore_id