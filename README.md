# terraform-eks-demo
This GitHub repository contains files that you can use to set up an EKS cluster with self managed EC2 worker nodes in an AWS region of your choice (by default, it's us-east-1). The worker nodes have a few system utilities installed via cloud-init, and have SELinux set to Enforce mode prior to the nodes joining the cluster. 

It also contains a simple application you can deploy into the Kubernetes cluster to test it out (it's a simple nginx server). 

Instructions are below on how you can get this setup and running. 

# How to get up and running

Step 1. Install [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), and [kubectl](https://kubernetes.io/docs/tasks/tools/) on your local machine. 

Step 2. Clone this git repo to your local machine. 

Step 3. Set up the proper AWS IAM role in your AWS account first (this is the role you'll assume when you're running the Terraform, and when you are administering the EKS cluster). 

Easiest way to do this is via the AWS Management Console CloudShell in your AWS account if you're logged in as root, or with a user account that has the AdministratorAccess role. 

Note your AWS account ID, we will use 0123456789012 as a placeholder. Change this to your AWS account's ID. You can use the existing `terraform.json` file in `/scripts/` which contains all needed permissions.

    aws iam create-role \
      --role-name TerraformRole \
      --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
          "Effect":"Allow",
          "Principal":{ "AWS":"arn:aws:iam::0123456789012:user/TerraformUser" },
          "Action":"sts:AssumeRole"
        }]
      }'
    
    # Attach the policy
    
    aws iam put-role-policy \
      --role-name TerraformRole \
      --policy-name TerraformPolicy \
      --policy-document file://terraform.json
    
    aws iam create-user --user-name TerraformUser
    
    # Allow it to sts:AssumeRole on TerraformRole
    
    aws iam put-user-policy \
      --user-name TerraformUser \
      --policy-name AllowAssumeTerraformRole \
      --policy-document '{
        "Version": "2012-10-17",
        "Statement":[ {
          "Effect":"Allow",
          "Action":"sts:AssumeRole",
          "Resource":"arn:aws:iam::0123456789012:role/TerraformRole"
        }]
      }'
      
      # Finally, generate access keys
      aws iam create-access-key --user-name TerraformUser
      # note the AccessKeyId and SecretAccessKey output here

It's also useful to update your local `~/.aws/config` file, where your profile can be stored. One way to do this is by `aws configure` and following the interactive prompts. Below is a sample `~/.aws/config` file you can also reference.

    [default]
    region = us-east-1
    output = json
    
    [profile terraform-role]
    role_arn = arn:aws:iam::0123456789012:role/TerraformRole
    source_profile = default
    region = us-east-1



Step 4. This step is *optional*, but **highly recommended**.  For security, it's worth changing the `cluster_endpoint_public_access_cidr` to your local IP address, to prevent the Kubernetes cluster endpoint from being accessible to anyone. Determine your IPv4 address by going to https://whatismyipaddress.com/. Under `module eks` in `main.tf`, change the value for `cluster_endpoint_public_access_cidr` to your IP address and use `/32` as the mask. 
   
    cluster_endpoint_public_access_cidrs  =  ["1.2.3.4/32"]


Step 5. Do a terraform plan followed by terraform apply to deploy the AWS infrastructure.

    terraform plan -var="env=dev"
    
    terraform apply -var="env=dev" 

Step 6. Once cluster is up, refresh your kubectl credentials check the nodes being online through kubectl get nodes, include instructions on how to set this up locally.

    # Get fresh credentials
    
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    
    aws sts assume-role \
      --role-arn arn:aws:iam::0123456789012:role/TerraformRole \
      --role-session-name eks-admin > credentials.json
    
    export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId credentials.json)
    export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey credentials.json)
    export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken credentials.json)
    
    # Update kubeconfig with explicit role credentials
    # Change --name and --region to your desired settings if they were different from the default
    
    aws eks update-kubeconfig --name dev-eks --region us-east-1

    # Check to see if your worker nodes are online
    
    kubectl get nodes

Step 7. Now once the nodes are online, go ahead and deploy the sample app through kubectl apply.

    kubectl apply -f app.yaml

Step 8. Check the deployment and service (kubectl get services), and go to the URL to make sure its online

    kubectl get services

Step 9. **You're done**. To clean up, delete your deployment (kubectl delete -f app.yaml), and then terraform destroy.

    # Clean up 
    kubectl delete -f app.yaml
    terraform destroy

  
  
  

# To refresh your kubectl credentials

You'll need do this after bringing up your EKS cluster for the first time, and periodically depending on how long you're working on the cluster. If you ever get an error preventing you from authenticating with the kubectl cluster, this is likely why.

    # Clear existing config
    rm ~/.kube/config
    
    # Get fresh credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    
    aws sts assume-role \
      --role-arn arn:aws:iam::0123456789012:role/TerraformRole \
      --role-session-name eks-admin > credentials.json
    
    export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId credentials.json)
    export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey credentials.json)
    export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken credentials.json)
    
    # Update kubeconfig with explicit role credentials
    # Change --name and --region to your desired settings if they were different from the default
    aws eks update-kubeconfig --name dev-eks --region us-east-1

Now you should be able to issue kubectl commands again without encountering authentication issues!



