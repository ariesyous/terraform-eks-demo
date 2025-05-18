# Run this from your bash console (or AWS CLI in the management console)

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

