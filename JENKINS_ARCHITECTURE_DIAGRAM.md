# Jenkins Project Architecture Diagram

## Mermaid Diagram

```mermaid
flowchart LR
    U[Developer / Admin] -->|terraform apply| TF[Terraform]
    U -->|opens Jenkins UI| JUI[Jenkins Dashboard :8080]
    U -->|pushes code| GIT[Git Repository]
    GIT -->|webhook on push / PR| WEBHOOK[Jenkins Webhook Trigger]

    subgraph AWS[AWS Cloud]
        subgraph VPC[VPC 10.0.0.0/16]
            subgraph S1[Public Subnet A 10.0.1.0/24]
                EC2[EC2 Ubuntu VM]
                JENKINS[Jenkins Container]
                TOOLS[Docker + AWS CLI + kubectl + eksctl + Trivy]
            end

            subgraph S2[Public Subnet B 10.0.2.0/24]
                EKS[EKS Managed Node Group]
            end

            IGW[Internet Gateway]
        end

        ECR[Amazon ECR Repository]
        EKSCP[Amazon EKS Cluster Control Plane]
        APP[Board Game App Pod]
        SVC[Kubernetes LoadBalancer Service]
        MON[Prometheus + Grafana<br/>Optional]
        SONAR[SonarQube Server<br/>External / Separately Managed]
        IAM[IAM Role for Jenkins EC2]
    end

    TF -->|provisions| VPC
    TF -->|creates| EC2
    TF -->|creates| ECR
    TF -->|creates| EKSCP
    TF -->|creates| EKS
    TF -->|optional Helm install| MON

    EC2 --> JENKINS
    EC2 --> TOOLS
    IAM --> EC2

    JUI --> JENKINS
    WEBHOOK -->|starts pipeline automatically| JENKINS
    GIT -->|checkout source| JENKINS
    JENKINS -->|mvn clean verify| GIT
    JENKINS -->|code analysis| SONAR
    JENKINS -->|docker build| ECR
    JENKINS -->|trivy scan| ECR
    JENKINS -->|push image| ECR
    JENKINS -->|kubectl deploy| EKSCP

    EKSCP --> EKS
    EKS --> APP
    APP --> SVC
    SVC -->|public access| U
    MON -->|scrapes / dashboards| EKS
    IGW --> EC2
    IGW --> SVC
```

## Pipeline Flow

```mermaid
flowchart TD
    A[Developer Pushes Code] --> B[Git Repository]
    B --> C[Webhook Sends Event to Jenkins]
    C --> D[Jenkins Pipeline Triggered Automatically]
    D --> E[Checkout Source]
    E --> F[Build and Unit Test]
    F --> G[SonarQube Analysis]
    G --> H[Quality Gate]
    H --> I[Build Docker Image]
    I --> J[Trivy Image Scan]
    J --> K[Push Image to Amazon ECR]
    K --> L[Update kubeconfig]
    L --> M[Render Kubernetes Manifest]
    M --> N[Deploy to Amazon EKS]
    N --> O[Board Game App Service Available]
```

## Short Description

- Terraform provisions the AWS network, EC2 Jenkins server, IAM roles, ECR, EKS, and optional monitoring.
- Jenkins runs on an EC2 instance inside Docker and acts as the CI/CD controller.
- A Git webhook triggers Jenkins automatically whenever code is pushed or a pull request event is configured.
- Jenkins builds the Spring Boot app, scans it, pushes the image to ECR, and deploys it to EKS.
- The application is exposed through a Kubernetes `LoadBalancer` service.
- Prometheus and Grafana can be enabled through `monitoring.tf`.

## Presentation Labels

Use these labels if you want to redraw this in PowerPoint:

- User / Developer
- Git Repository
- Webhook Trigger
- Terraform
- AWS Cloud
- VPC
- Public Subnet A
- Public Subnet B
- Jenkins EC2 Instance
- Jenkins Container
- Docker / AWS CLI / kubectl / eksctl / Trivy
- IAM Role
- Amazon ECR
- Amazon EKS Control Plane
- EKS Node Group
- Board Game Application
- Kubernetes LoadBalancer Service
- Prometheus
- Grafana
- SonarQube
