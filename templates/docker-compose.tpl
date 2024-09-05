version: "3.9"

services:
  vault:
    container_name: vault
    hostname: vault2.example.com
    image: hashicorp/vault-enterprise:1.16.7-ent
    restart: unless-stopped
    ports:
      - 8200:8200
      - 8201:8201
    volumes:
      - ./vault/data:/vault/data
      - ./vault/conf:/vault/conf
      - ./vault/audit:/vault/audit
      - ./vault/plugins:/vault/plugins
      - ./certs:/certs
      - ./vault.hclic:/vault.hclic
    environment:
      - VAULT_ADDR=https://vault2.example.com:8200
      - VAULT_API_ADDR=https://vault2.example.com:8200
      - VAULT_CLUSTER_ADDR=https://vault2.example.com:8201
      - VAULT_SKIP_VERIFY=true
      - VAULT_UI=true
      - VAULT_LICENSE_PATH=/vault.hclic
    command: vault server -config=/vault/conf/vault.hcl

  openldap:
    container_name: openldap
    hostname: openldap2.example.com
    image: bitnami/openldap:2.6.6
    restart: unless-stopped
    volumes:
      - ./openldap:/bitnami/openldap
      - ./certs:/certs
    ports:
      - 636:636
      - 389:389
    environment:
      - LDAP_ADMIN_USERNAME=admin
      - LDAP_ADMIN_PASSWORD=password
      - LDAP_USERS=${ldap_users}
      - LDAP_PASSWORDS=${ldap_users}
      - LDAP_ROOT=dc=example,dc=com
      - LDAP_USER_DC=users
      - LDAP_GROUP=engineers
      - LDAP_ADMIN_DN=cn=admin,dc=example,dc=com
      - LDAP_PORT_NUMBER=389
      - LDAP_ENABLE_TLS=yes
      - LDAP_REQUIRE_TLS=no
      - LDAP_LDAPS_PORT_NUMBER=636
      - LDAP_TLS_KEY_FILE=/certs/privkey.pem
      - LDAP_TLS_CERT_FILE=/certs/certificate.pem
      - LDAP_TLS_CA_FILE=/certs/ca.pem
