# Flask - ECS Template

Simple terraform template to host a flask app to ECS Fargate.

## Create docker image

Run script to create and publish docker image:

``` bash
chmod +x publish-docker-image.sh
sh ./publish-docker-image.sh
```

## Configure the AWS Infrastructure

Create `prod_variables.tfvars` file:

``` tfvars
subnets = ["subnet-1", "subnet-2"]
vpc_id = "vpc-1"
region = "us-east-1"
docker_image = "public.ecr.aws/o2n5f4o6/flask-app:latest"
account_id = "123456789102"
```

## Terraform - Infrastructure

1. Initialize the Terraform working directory:

``` bash
terraform init
```

2. Preview the changes that will be applied:

``` bash
terraform plan
```

3. Apply the changes and create the infrastructure:

``` bash
terraform apply -var-file="prod_variables.tfvars"
```

---
Developed by [@jjeanjacques10](https://github.com/jjeanjacques10)
