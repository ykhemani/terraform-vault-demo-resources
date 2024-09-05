variable "app_count" {
  type        = number
  description = "Number of app entities to create."
  default     = 10
}

variable "human_count" {
  type        = number
  description = "Number of human entities to create."
  default     = 20
}

variable "namespace_count" {
  type        = number
  description = "Number of namespaces to create."
  default     = 5
}

variable "ldap_user_vault_admin" {
  type        = string
  description = "Vault LDAP Admin user"
  default     = "yash"
}

variable "ldap_users" {
  type        = string
  description = "Comma separated list of ldap users."
  default     = "yash,buffalo,gorilla,spider,vulture,bonefish,mastiff,shiner,clam,stallion,yak,porpoise,shark,feline,owl,anchovy,sawfish,walleye,penguin,chow,ray"
}

variable "suffix" {
  type        = string
  description = "File naming suffix."
  default     = "suffix"
}

locals {
  humans     = join(",", concat([var.ldap_user_vault_admin], random_pet.human[*].id))
  ldap_users = split(",", var.ldap_users)
}
#

resource "random_pet" "app" {
  count  = var.app_count
  length = 2
}

resource "vault_identity_entity" "app" {
  count = var.app_count
  name  = random_pet.app[count.index].id
  #policies = [random_pet.app[count.index].id]
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "role" {
  count          = var.app_count
  backend        = vault_auth_backend.approle.path
  role_name      = random_pet.app[count.index].id
  token_policies = ["default", random_pet.app[count.index].id]
}

resource "vault_identity_entity_alias" "app_alias" {
  count          = var.app_count
  name           = random_pet.app[count.index].id
  mount_accessor = vault_auth_backend.approle.accessor
  canonical_id   = vault_identity_entity.app[count.index].id
}

#

resource "random_pet" "human" {
  count  = var.human_count
  length = 1
}

resource "vault_identity_entity" "human" {
  count = var.human_count
  name  = random_pet.human[count.index].id
  #for_each = toset(local.ldap_users)
  #name = each.key
  #policies = [random_pet.human[count.index].id]
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_ldap_auth_backend" "ldap" {
  path      = "ldap"
  url       = "ldap://openldap2.example.com"
  binddn    = "cn=admin,dc=example,dc=com"
  bindpass  = "password"
  userattr  = "uid"
  userdn    = "ou=users,dc=example,dc=com"
  groupdn   = "ou=users,dc=example,dc=com"
  groupattr = "groupOfNames"
}

resource "vault_identity_entity" "yash" {
  name = "yash"
}

resource "vault_ldap_auth_backend_user" "yash" {
  username = "yash"
  policies = ["yash", "default"]
  backend  = vault_ldap_auth_backend.ldap.path
}

resource "vault_policy" "yash" {
  name   = "yash"
  policy = <<EOT
# full admin rights
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

EOT
}

resource "vault_identity_entity_alias" "yash" {
  name           = "yash"
  canonical_id   = vault_identity_entity.yash.id
  mount_accessor = vault_ldap_auth_backend.ldap.accessor
}

resource "vault_identity_entity_alias" "human_alias" {
  count          = var.human_count
  name           = random_pet.human[count.index].id
  canonical_id   = vault_identity_entity.human[count.index].id
  mount_accessor = vault_ldap_auth_backend.ldap.accessor
}

resource "vault_ldap_auth_backend_user" "user" {
  count    = var.human_count
  username = random_pet.human[count.index].id
  policies = [random_pet.human[count.index].id, "default"]
  backend  = vault_ldap_auth_backend.ldap.path
}

resource "vault_policy" "policy" {
  count  = var.human_count
  name   = random_pet.human[count.index].id
  policy = <<EOT
path "${vault_mount.kv.path}/metadata/${random_pet.human[count.index].id}" {
  capabilities = ["list"]
}

path "${vault_mount.kv.path}/data/${random_pet.human[count.index].id}/*" {
  capabilities = ["read", "list", "update", "create","delete"]
}

EOT
}

resource "vault_mount" "kv" {
  path    = "kv"
  type    = "kv"
  options = { version = "2" }
}

resource "vault_kv_secret_v2" "secret" {
  count = var.human_count
  name  = "${random_pet.human[count.index].id}/${random_pet.human[count.index].id}"
  mount = vault_mount.kv.path
  data_json = jsonencode(
    {
      zip = "${random_pet.human[count.index].id}",
      foo = "bar"
    }
  )

}

resource "local_file" "docker-compose" {
  filename = "${path.module}/docker-compose-${var.suffix}.yaml"
  content = templatefile("${path.module}/templates/docker-compose.tpl",
    {
      ldap_users = local.humans
  })
}

# login with approle auth
resource "vault_approle_auth_backend_role_secret_id" "id" {
  count     = var.app_count
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.role[count.index].role_name
}

resource "vault_approle_auth_backend_login" "approle_login" {
  count     = var.app_count
  backend   = vault_auth_backend.approle.path
  role_id   = vault_approle_auth_backend_role.role[count.index].role_id
  secret_id = vault_approle_auth_backend_role_secret_id.id[count.index].secret_id
}

resource "local_file" "approle_login" {
  filename = "${path.module}/approle_login-${var.suffix}"
  content = templatefile("${path.module}/templates/approle_login.tpl",
    {
      approle_tokens = vault_approle_auth_backend_login.approle_login[*].client_token
  })
}

resource "local_file" "ldap_login" {
  filename = "${path.module}/ldap_login-${var.suffix}"
  content = templatefile("${path.module}/templates/ldap_login.tpl",
    {
      ldap_users = random_pet.human[*].id
  })
}

resource "random_pet" "namespace" {
  count  = var.namespace_count
  length = 1
}

resource "vault_namespace" "namespace" {
  count = var.namespace_count
  path  = random_pet.namespace[count.index].id
}