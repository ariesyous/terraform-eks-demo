# terraform-eks-demo
This GitHub repository contains files that you can use to set up an EKS cluster with self managed EC2 worker nodes in an AWS region of your choice (by default, it's us-east-1). The worker nodes have a few system utilities installed via cloud-init, and have SELinux set to Enforce mode prior to the nodes joining the cluster. 

It also contains a simple application you can deploy into the Kubernetes cluster to test it out (it's a simple nginx server). 

Instructions are below on how you can get this setup and running. For an FAQ, scroll down or click [here](#FAQ).

# How to get up and running

Step 1. Install [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), and [kubectl](https://kubernetes.io/docs/tasks/tools/) on your local machine. 

Step 2. Clone this git repo to your local machine. 

Step 3. Set up the proper AWS IAM role in your AWS account first (this is the role you'll assume when you're running the Terraform, and when you are administering the EKS cluster). 

Easiest way to do this is via the AWS Management Console CloudShell in your AWS account if you're logged in as root, or with a user account that has the AdministratorAccess role. Use the existing `terraform.json` file in the `/scripts/` folder which contains all needed permissions. You can copy and paste the entire terraform.json file into your AWS CloudShell's home directory, and run the commands below in order to reference them when setting up your `TerraformRole` credentials.

Note your AWS account ID, we will use 0123456789012 as a placeholder. Change this to your AWS account's ID. 

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

    # Make sure you have the terraform.json from the /scripts/ folder present in CloudShell before running this command
    
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


Step 5. Step 5. From the root of the repository folder, do a terraform init to pull all needed Terraform modules, followed by terraform plan and apply to deploy the AWS infrastructure. You can optionally specify a unique environment for each cluster if you'd prefer (eg, dev, stage, prod), but default will be dev if you omit the variable.

    terraform init
    
    terraform plan -var="env=dev"
    
    terraform apply -var="env=dev" 

This will take about 5-10 minutes to set up all necessary components, including the Kubernetes cluster itself.

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

## FAQ

### Q: What is Terraform and why are we using it here?

**A:** Terraform is an “infrastructure as code” tool that lets you describe AWS resources (VPCs, EKS clusters, IAM roles, etc.) in simple configuration files. When you run `terraform apply`, Terraform creates, updates, or destroys those resources for you—so you never have to click around in the Console. It keeps track of what’s been applied and shows you a plan before making changes.

### Q: What is Amazon EKS?

**A:** EKS (Elastic Kubernetes Service) is AWS’s managed Kubernetes control plane. It runs `etcd`, `kube‑apiserver`, `controller-manager`, etc., in AWS‑managed accounts, and exposes a highly available API endpoint. You still need to supply “worker nodes” (EC2 instances) to actually run your containers.

### Q: What is **cloud‑init** and how does it work with EC2?

**A:** Cloud‑init is the “user‑data” engine on most AWS AMIs. When an EC2 instance first boots, it looks at the `user_data` you provided (our bootstrap script) and executes it. We inject our security updates, custom tooling installs, and SELinux configuration here _before_ the node runs `kubeadm join`.

### Q: Why do we use **self‑managed** worker nodes instead of EKS **managed node groups**?

**A:** Self‑managed nodes give you full control over the EC2 instances, the AMI they use, and their user‑data (e.g. SELinux enforcement, custom tools, etc.). Managed node groups are easier to stand up, but less flexible if you need to run custom bootstrap logic.

### Q: What is **SELinux**, and why enforce it on EKS nodes?

**A:** SELinux is a Linux kernel feature that confines processes to strict security policies. By switching from “permissive” to “enforcing” mode, we reduce the blast radius if one of our processes is compromised. Enforcing mode ensures `kubelet`, `containerd`, and your workloads only have the minimal permissions they need.

### Q: How much will running this EKS cluster cost me?

**A:** Rough estimates (prices at May 2025, US‑East 1):

-   Control plane: **$0.10/hour** (~$72 USD/month)
    
-   EC2 t3.medium nodes: **$0.0416/hour** each (~$30 USD/month per node)
    
-   NAT Gateway, Data Transfer, EBS volumes, etc., will add extra.  
    Always tear down with `terraform destroy` when you’re not using it!

### Q: Approximately how long does deployment take?

**A:**

-   **Terraform apply**: 5–10 minutes to create VPC, IAM, and control plane.
    
-   **Node boot & join**: another 5–7 minutes per node (cloud‑init, security updates, SELinux enforcement, kubeadm join).  
    Total: roughly 10–15 minutes.

### Q: I’m seeing `Error: Unauthorized` or `AccessDenied`; what do I check?

1.  **Are you using the right AWS credentials?**
    
    -   Confirm you’ve `aws sts assume-role` into the `TerraformRole`.
        
    -   Check `echo $AWS_ACCESS_KEY_ID` matches what you expect.
        
2.  **Does your role have the necessary policies?**
    
    -   Review the attached IAM policy in the bootstrap role; make sure it includes `eks:*`, `ec2:*`, `iam:PassRole`, etc.

### Q: How can I customize the cluster name or environment?

Edit the `-var="env=dev"` on the command line (e.g. `-var="env=staging"`), and Terraform will automatically prefix the VPC, cluster, and node‑group names with that string.

### Q: Where do I find the sample application manifests?

They live in the repo at **`app.yaml`** (an Nginx Deployment + Service). You can modify that file or point to your own `.yaml` under **Step 7**.

### Q: How do I access the sample application once it’s deployed?

1.  Run `kubectl get svc nginx-svc -o wide` to see its **EXTERNAL-IP**.
    
2.  Open that IP in your browser on port 80.
    
    -   If you see a default Nginx page, you’re all set!

### Q: How do I update the bootstrap script or install additional tools?

-   Edit your shell snippet in the `cloudinit_pre_nodeadm` (or inline HEREDOC) block in `main.tf`.
    
-   Set `force_update_version = true` under your node‑group to roll out a new launch template version.
    
-   Run `terraform apply` again; your nodes will be replaced with the updated user‑data.



### Q: Which AWS credentials does Terraform use?

Terraform will use the AWS CLI’s default credential chain. You can either export `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (and `AWS_SESSION_TOKEN` if you’re assuming a role), or configure a profile in `~/.aws/config` and run:

`AWS_PROFILE=terraform-role terraform plan ‑var="env=dev"`

### Q: Why do I need to assume an IAM role before running Terraform?

Following best practices, we create a dedicated **TerraformRole** (with exactly the permissions your scripts need). You assume that role to get short‑lived credentials, instead of using long‑lived root or user keys. See **Step 3** in the README for how to `sts assume-role`.

### Q: How do I restrict access to my EKS control plane?

Edit the `cluster_endpoint_public_access_cidrs` list in `main.tf` to only include your IP (e.g. `["1.2.3.4/32"]`). Then `terraform apply`—the API server will refuse connections from any other source.

### Q: How can I change the AWS region or account?

-   **Region**: either set `AWS_DEFAULT_REGION`, configure it in `~/.aws/config`, or pass `-var="region=us-west-2"` if you add a `region` variable.
    
-   **Account**: Terraform writes resources into whichever AWS account your credentials point at; switch profiles or assume a different role for another account.


### Q: How do I tear everything down?

1.  Delete your test app:
    
    `kubectl delete -f app.yaml` 
    
2.  Destroy all Terraform‑managed resources:
    
    `terraform destroy -var="env=dev"` 
    
    This will remove the EKS cluster, nodes, VPC, and IAM roles you created.

### Q: Where can I go for more help?

-   **Terraform docs**: [https://registry.terraform.io/](https://registry.terraform.io/)
    
-   **AWS EKS User Guide**: [https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
    
-   **Kubernetes docs**: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
    
-   **Cloud‑Init reference**: [https://cloudinit.readthedocs.io/](https://cloudinit.readthedocs.io/)



