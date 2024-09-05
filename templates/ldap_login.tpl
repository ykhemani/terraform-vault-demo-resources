#!/bin/bash

%{for ldap_user in ldap_users ~}
export VAULT_TOKEN=$(vault login -format=json -method=ldap username=${ldap_user} password=${ldap_user} | jq -r .auth.client_token)
VAULT_TOKEN=$VAULT_TOKEN vault token lookup
VAULT_TOKEN=$VAULT_TOKEN vault kv get kv/${ldap_user}/${ldap_user}
%{ endfor ~}
