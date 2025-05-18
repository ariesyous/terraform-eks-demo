provider "aws" {
  region  = var.aws_region
  profile = "terraform-role"
  # or you can embed the assume_role here:
  # assume_role {
  #   role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/TerraformRole"
  # }
}