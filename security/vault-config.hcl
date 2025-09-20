# HashiCorp Vault Configuration
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = false
  tls_cert_file = "/etc/vault/tls/vault.crt"
  tls_key_file  = "/etc/vault/tls/vault.key"
}

seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-unseal-key"
}

api_addr = "https://vault.normaldance.com:8200"
cluster_addr = "https://vault.normaldance.com:8201"

ui = true

# Enable audit logging
audit {
  file {
    file_path = "/vault/logs/audit.log"
    log_raw = false
  }
}

# Secret engines
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "pki/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Policies
policy "normaldance-app" {
  path "secret/data/normaldance/*" {
    capabilities = ["read"]
  }
  
  path "database/creds/normaldance-role" {
    capabilities = ["read"]
  }
  
  path "pki/issue/normaldance-dot-com" {
    capabilities = ["create", "update"]
  }
}

policy "normaldance-admin" {
  path "secret/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
  }
  
  path "sys/policies/acl/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
  }
  
  path "auth/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
}

# Authentication methods
auth "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
  
  config {
    kubernetes_host = "https://kubernetes.default.svc"
    kubernetes_ca_cert = file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
    token_reviewer_jwt = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
  }
}

auth "oidc" {
  type = "oidc"
  path = "oidc"
  
  config {
    oidc_discovery_url = "https://auth.normaldance.com"
    oidc_client_id = "vault"
    oidc_client_secret = "vault-oidc-secret"
    default_role = "normaldance-user"
  }
}