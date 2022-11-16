module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "18.26.3"
  cluster_name                    = var.deployment_id
  cluster_version                 = "1.22"
  vpc_id                          = var.vpc_id
  subnet_ids                      = [var.private_subnets[0], var.private_subnets[1]]
  cluster_endpoint_private_access = true
  cluster_service_ipv4_cidr       = "172.20.0.0/18"

  eks_managed_node_group_defaults = {
  }
  cluster_security_group_additional_rules = {
    ops_private_access_egress = {
      description = "Ops Private Egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = [var.vpc_cidr]
    }
    ops_private_access_ingress = {
      description = "Ops Private Ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
  }
  eks_managed_node_groups = {
    default = {
      min_size               = 1
      max_size               = 3
      desired_size           = 2
      instance_types         = ["t3.micro"]
      key_name               = var.aws_keypair_keyname
      vpc_security_group_ids = [module.private-ssh.security_group_id]
    }
  }

  tags = {
    owner = var.owner
  }
}

# The Kubernetes provider is included here so the EKS module can complete successfully. Otherwise, it throws an error when creating `kubernetes_config_map.aws_auth`.
# Retrieve EKS cluster configuration
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_service_account_v1" "vault" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}


resource "kubernetes_cluster_role_v1" "vault_role" {
  metadata {
    name = "k8s-full-secrets-abilities-with-labels"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "serviceaccounts/token"]
    verbs      = ["create", "update", "delete"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings", "clusterrolebindings"]
    verbs      = ["create", "update", "delete"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "clusterroles"]
    verbs      = ["bind", "escalate", "create", "update", "delete"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "vault_role_binding" {
  metadata {
    name = "k8s-full-secrets-abilities-with-labels"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "k8s-full-secrets-abilities-with-labels"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "${kubernetes_service_account_v1.vault.metadata.0.name}"
    namespace = "${kubernetes_service_account_v1.vault.metadata.0.namespace}"
  }
}

data "kubernetes_secret_v1" "vault" {
  metadata {
    name = "${kubernetes_service_account_v1.vault.default_secret_name}"
    namespace = "${kubernetes_service_account_v1.vault.metadata.0.namespace}"
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

resource "local_file" "vault_k8s_token" {
  filename = "${path.root}/generated/vault-k8s-token"
  content = "${data.kubernetes_secret_v1.vault.data.token}"
}

resource "local_file" "k8s_ca_cert" {
  filename = "${path.root}/generated/k8s_ca.crt"
  content = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${var.deployment_id} --kubeconfig ${path.root}/kubeconfig"
  }

  depends_on = [
    module.eks
  ]
}

