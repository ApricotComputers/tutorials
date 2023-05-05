module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.13.1"

  cluster_name    = "my-cluster"
  cluster_version = "1.26"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 5
      desired_size = 2

      instance_types = ["t3a.large"]
      capacity_type  = "SPOT"
    }
  }
}
