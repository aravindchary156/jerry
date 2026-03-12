# Jenkins-Based DevOps Project Documentation

## 1. Project Overview

This project provisions a Jenkins-centered CI/CD environment on AWS using Terraform and deploys a Spring Boot application to Amazon EKS. The repository combines infrastructure provisioning, Jenkins automation, container image management, Kubernetes deployment, and optional monitoring in one place.

The application inside `board/` is a board game review platform built with Spring Boot, Thymeleaf, Spring Security, JDBC, and an H2 in-memory database. Jenkins is used as the orchestration layer for build, test, code analysis, containerization, image scanning, image publishing, and Kubernetes deployment.

## 2. Project Goals

- Provision AWS infrastructure with Terraform
- Host Jenkins on an EC2 instance
- Build and test the Java application with Maven
- Perform static analysis with SonarQube
- Scan container images with Trivy
- Push versioned Docker images to Amazon ECR
- Deploy the application to Amazon EKS
- Optionally install Prometheus and Grafana for monitoring

## 3. High-Level Architecture

The platform consists of the following layers:

- AWS VPC with two public subnets across two availability zones
- EC2 instance running Jenkins in Docker
- IAM role and instance profile for Jenkins access to ECR and EKS
- Amazon ECR repository for Docker image storage
- Amazon EKS cluster with a managed node group
- Kubernetes service of type `LoadBalancer` for application exposure
- Optional `kube-prometheus-stack` Helm deployment for monitoring

Flow summary:

1. Terraform provisions networking, security, EC2, IAM, ECR, EKS, and optional monitoring.
2. The EC2 bootstrap script installs Docker, Java, AWS CLI, `kubectl`, `eksctl`, and Trivy, then starts Jenkins as a Docker container.
3. Jenkins pulls the application source, runs tests and analysis, builds a Docker image, pushes it to ECR, and deploys it to EKS.
4. The application is exposed through a Kubernetes `LoadBalancer` service.

## 4. Repository Structure

- `main.tf`: VPC, subnets, internet gateway, route table, and subnet associations
- `nsg.tf`: Security group for EC2/Jenkins and exposed tooling ports
- `vm.tf`: Jenkins EC2 instance and Ubuntu AMI lookup
- `jenkins_iam.tf`: IAM role and instance profile for Jenkins EC2
- `ecr.tf`: ECR repository and lifecycle policy
- `eks.tf`: EKS control plane, node group, and Jenkins cluster access
- `monitoring.tf`: Optional Prometheus and Grafana installation using Helm
- `provisioners.tf`: Copies and runs the EC2 bootstrap script
- `install_tools.sh`: Installs tools and launches Jenkins in Docker
- `variable.tf`: Terraform variables
- `terraform.tfvars`: Environment-specific variable values
- `output.tf`: Terraform outputs for access and operations
- `board/`: Spring Boot application source code
- `board/Jenkinsfile`: Jenkins pipeline definition
- `board/Dockerfile`: Container build definition
- `board/k8s/deployment-service.yaml`: Kubernetes deployment and service manifest
- `board/sonar-project.properties`: SonarQube analysis settings

## 5. Infrastructure Details

### 5.1 Networking

The project creates a VPC with CIDR `10.0.0.0/16` and two public subnets:

- `10.0.1.0/24` in the first available AZ
- `10.0.2.0/24` in the second available AZ

Both subnets are associated with a route table that routes `0.0.0.0/0` through an internet gateway. They are tagged for Kubernetes external load balancer usage.

### 5.2 Security Group

The main security group allows inbound access to:

- `22` for SSH
- `80` and `443` for HTTP/HTTPS
- `8080` for Jenkins
- `3000` for Grafana
- `9090` for Prometheus
- `9000` for SonarQube

Outbound traffic is fully open.

Note: SSH is controlled by `allowed_ssh_cidrs`, but the default value is `0.0.0.0/0`. This should be restricted in real environments.

### 5.3 Jenkins EC2 Instance

Terraform provisions one Ubuntu 22.04 EC2 instance:

- Public IP enabled
- Root disk size `100 GB` with `gp3`
- IAM instance profile attached
- Located in the first public subnet

The bootstrap process installs:

- Docker
- OpenJDK 17 runtime
- AWS CLI
- Trivy
- `kubectl`
- `eksctl`
- Jenkins as Docker container `jenkins/jenkins:lts-jdk17`

Jenkins runs on:

- Port `8080` for web access
- Port `50000` for agent communication

### 5.4 IAM and Access Model

The EC2 instance role is granted:

- `AmazonEC2ContainerRegistryPowerUser`
- `AmazonEKSClusterPolicy`

EKS also creates:

- A cluster IAM role
- A node group IAM role
- An EKS access entry for the Jenkins EC2 role
- Cluster-wide admin access for Jenkins through `AmazonEKSClusterAdminPolicy`

This lets Jenkins authenticate to EKS and perform deployments from the EC2 host.

### 5.5 Amazon ECR

The repository creates one ECR repository for the application image:

- Mutable image tags
- Scan on push enabled
- Lifecycle policy retains the latest 20 images

### 5.6 Amazon EKS

The EKS stack includes:

- One cluster
- One managed node group
- Configurable instance types and scaling values

Current `terraform.tfvars` values:

- Region: `ap-south-1`
- Cluster name: `hackathon-eks`
- Node instance type: `t3.small`
- Desired nodes: `3`
- Min nodes: `3`
- Max nodes: `4`

## 6. Monitoring Stack

Monitoring is implemented in `monitoring.tf` using the Helm provider.

When `install_monitoring_stack = true`, Terraform creates:

- Namespace: `monitoring`
- Helm release: `kube-prometheus-stack`
- Grafana service exposed as `LoadBalancer`
- Prometheus service exposed as `LoadBalancer`

The chart version is pinned to `69.8.2`.

Important note:

- `variable.tf` defaults monitoring to `true`
- `terraform.tfvars` currently overrides it to `false`

That means monitoring is disabled in the current checked-in environment unless explicitly enabled.

## 7. Application Overview

The application in `board/` is a board game listing and review system.

Core capabilities:

- View board games and reviews without authentication
- User role can add board games and reviews
- Manager role can edit and delete reviews
- Spring Security-based authentication and authorization
- Thymeleaf server-side rendering
- JDBC access with schema initialization via `schema.sql`
- H2 in-memory database

Default sample credentials from the application README:

- User: `bugs` / `bunny`
- Manager: `daffy` / `duck`

## 8. CI/CD Pipeline Design

The Jenkins pipeline is defined in `board/Jenkinsfile`.

### 8.1 Pipeline Stages

1. `Checkout`
   - Pulls the repository from source control

2. `Build + Unit Test`
   - Runs `mvn -B clean verify` inside `board/`

3. `SonarQube Analysis`
   - Executes Maven Sonar analysis using a Jenkins secret token

4. `Quality Gate`
   - Waits for SonarQube quality gate result and aborts on failure

5. `Build Docker Image`
   - Builds the application image from `board/Dockerfile`
   - Tags it locally and with the full ECR URI

6. `Trivy Image Scan`
   - Scans the built image for `CRITICAL` vulnerabilities
   - Does not fail the build because `--exit-code 0` is used

7. `AWS Identity Check`
   - Validates AWS credentials using `sts get-caller-identity`

8. `Push Image To ECR`
   - Ensures the ECR repository exists
   - Logs Docker into ECR
   - Pushes the versioned image

9. `Deploy To EKS`
   - Updates AWS CLI if CLI v1 is detected
   - Attempts node group scaling update
   - Waits for node group status to become active
   - Updates kubeconfig
   - Replaces `IMAGE_PLACEHOLDER` in the Kubernetes manifest
   - Applies the rendered deployment
   - Waits for rollout completion and prints diagnostics on failure

### 8.2 Image Versioning

The image tag is derived from Jenkins `BUILD_NUMBER`, which provides simple build-to-image traceability.

Example image pattern:

`049419513053.dkr.ecr.ap-south-1.amazonaws.com/boardgame:<BUILD_NUMBER>`

### 8.3 Pipeline Cleanup

In the `post` block, Jenkins always:

- Prunes unused Docker images
- Prunes builder cache
- Deletes the Trivy cache directory

This helps control disk usage on the EC2 instance.

## 9. Jenkins Prerequisites

Before the pipeline can run successfully, Jenkins needs some manual setup.

### 9.1 Initial Access

After Terraform apply, obtain the Jenkins URL:

```bash
terraform output jenkins_url
```

Get the initial admin password:

```bash
terraform output jenkins_initial_admin_password_command
```

Run the printed SSH command in a terminal.

### 9.2 Recommended Jenkins Plugins

Install at least the following plugin categories:

- Pipeline
- Git
- Docker Pipeline
- SonarQube Scanner for Jenkins
- Credentials Binding
- Pipeline: Stage View

### 9.3 Jenkins Credentials and Global Configuration

Required Jenkins configuration includes:

- A SonarQube server named `sonarqube-server`
- A secret text credential with ID `sonar-token`
- A Jenkins node or executor labeled `linux`

If the pipeline is run on the built-in Jenkins container host, ensure the job can execute Docker, AWS CLI, `kubectl`, and Maven commands in that environment.

Operational note:

- Jenkins itself runs inside Docker
- The host has Docker installed
- Additional Jenkins container customization may be needed so pipeline steps can access Docker and other CLI tools consistently

## 10. Kubernetes Deployment Details

The application manifest is in `board/k8s/deployment-service.yaml`.

Deployment characteristics:

- Deployment name: `boardgame-deployment`
- One replica
- Rolling update strategy with `maxUnavailable: 1`
- Container port `8080`
- `imagePullPolicy: Always`
- CPU request `100m`, limit `500m`
- Memory request `128Mi`, limit `512Mi`

Health checks:

- Startup probe on `/`
- Liveness probe on `/`
- Readiness probe on `/`

Service characteristics:

- Service name: `boardgame-service`
- Type: `LoadBalancer`
- Exposes port `80` to container port `8080`

## 11. Provisioning and Execution Steps

### 11.1 Infrastructure Provisioning

```bash
cd /Users/maravind/Hackathon
terraform init -upgrade
terraform plan
terraform apply
```

### 11.2 Access Terraform Outputs

Useful outputs include:

- `instance_public_ip`
- `instance_id`
- `vpc_id`
- `security_group_id`
- `ssh_command`
- `jenkins_url`
- `jenkins_initial_admin_password_command`
- `ecr_repository_url`
- `eks_cluster_name`
- `eks_update_kubeconfig_command`
- `monitoring_namespace`
- `grafana_service_name`
- `prometheus_service_name`

### 11.3 Configure `kubectl`

```bash
terraform output -raw eks_update_kubeconfig_command
```

Run the resulting command locally to configure Kubernetes access.

### 11.4 Run the CI/CD Pipeline

1. Create or connect the Jenkins pipeline job to this repository
2. Point it to `board/Jenkinsfile`
3. Trigger a build
4. Monitor each pipeline stage
5. Validate deployment in EKS

### 11.5 Verify Application Deployment

Typical checks:

```bash
kubectl get pods
kubectl get svc
kubectl describe deployment boardgame-deployment
```

## 12. Important Operational Notes

- The file name `prrovider.tf` is intentionally spelled with a double `r` in this repository.
- The EC2 resource ignores `instance_type` changes because of `lifecycle { ignore_changes = [instance_type] }`.
- The pipeline hardcodes AWS account ID, region, repository name, cluster name, and node group name in `board/Jenkinsfile`.
- The pipeline attempts to scale the node group to `min=2`, `max=3`, `desired=2` during deployment, which differs from the current Terraform values.
- Trivy scanning is informational right now because it does not fail the build on vulnerabilities.
- SonarQube is referenced by the pipeline, but SonarQube infrastructure is not provisioned by Terraform in this repository.
- Jenkins is deployed as a Docker container instead of a native package installation.

## 13. Risks and Improvement Opportunities

The project works as a complete demo platform, but the following improvements are recommended for production-readiness:

- Restrict SSH CIDRs instead of allowing global access
- Move hardcoded Jenkinsfile environment values to Jenkins parameters or Terraform-generated variables
- Provision SonarQube separately or remove the mandatory stage when SonarQube is unavailable
- Make Trivy fail the build for defined severity thresholds
- Use private subnets and a more production-grade VPC layout for EKS worker nodes
- Add TLS, DNS, and Ingress for the application instead of exposing services directly as public load balancers
- Store application and infrastructure secrets in AWS Secrets Manager or Parameter Store
- Add backup and persistence strategy if Jenkins data must survive host replacement
- Add remote Terraform state and state locking if multiple users will manage infrastructure

## 14. Conclusion

This repository demonstrates an end-to-end Jenkins-based DevOps workflow on AWS. Terraform provisions the base infrastructure, Jenkins automates the software delivery lifecycle, ECR stores versioned images, EKS runs the application, and the monitoring stack can be enabled when needed. It is a strong learning and demonstration project for CI/CD, containerization, infrastructure as code, and Kubernetes deployment on AWS.
