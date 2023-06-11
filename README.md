# Flask - ECS Template

This repository provides a simple Terraform template for hosting a Flask app on ECS Fargate, along with the necessary infrastructure components like Network Load Balancer and API Gateway.

## Resources

- ECS - Fargate
- Network Load Balancer
- API Gateway

## Create docker image

Replace `YOUR_USERNAME` with your Docker Hub username in the [./code/publish-docker-image.sh](./code/publish-docker-image.sh)

``` bash
# Replace YOUR_USERNAME with your Docker Hub username
DOCKER_USERNAME=YOUR_USERNAME
```

Run the script to create and publish the Docker image:

``` bash
chmod +x publish-docker-image.sh
sh ./publish-docker-image.sh
```

## Configure the AWS Infrastructure

Create a file named `prod_variables.tfvars` and provide the necessary configuration values:

``` tfvars
subnets = ["subnet-1", "subnet-2"]
vpc_id = "vpc-1"
region = "us-east-1"
docker_image = "jjeanjacques10/flask-app-hello:latest"
account_id = "123456789102"
```

## Terraform - Infrastructure

Follow these steps to provision the infrastructure using Terraform:

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

## References

- <https://registry.terraform.io/providers/hashicorp/aws>

---
Developed by [@jjeanjacques10](https://github.com/jjeanjacques10)
