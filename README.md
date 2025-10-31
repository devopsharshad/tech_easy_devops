# 🚀 DevOps Assignment — Terraform EC2 Deployment (Auto Env Selection)

This project automates the provisioning and configuration of an **AWS EC2 instance** using **Terraform**.  
It installs all dependencies, clones a sample Java application from GitHub, builds it using Maven, and runs it automatically on port **80**.  
It also supports **automatic environment selection (dev/prod)** using a single script `deploy.sh`.

---

## 🧠 Project Overview

This setup demonstrates Infrastructure as Code (IaC) using **Terraform** to deploy a Java application on AWS.

**Key Highlights:**
- Uses Terraform to launch EC2 instances for **Dev** and **Prod** environments.
- Installs **Java 21 (Amazon Corretto)**, **Maven**, and **Git**.
- Clones a public GitHub repository and builds the app automatically.
- Runs the app in the background and tests reachability on port 80.
- Auto-shuts down the instance after 30 minutes to save cost.
- No hard-coded credentials — uses AWS CLI profile authentication.
- Supports **UI/CLI-based environment selection** (`dev` or `prod`).

---

## 📁 Folder Structure

```
terraform-ec2-deployment/
├── main.tf
├── provider.tf
├── variable.tf
├── dev.tfvars
├── prod.tfvars
├── setup.sh
├── deploy.sh
└── README.md
```

---

## ⚙️ Prerequisites

Before you begin, make sure you have:

1. ✅ **AWS Account** (Free Tier)
2. ✅ **AWS CLI** installed and configured:
   ```bash
   aws configure
   ```
   Use your credentials and region (e.g., `ap-south-1`).
3. ✅ **Terraform** installed (v1.5+ recommended)
4. ✅ **Git Bash** installed (for running .sh scripts on Windows)

---

## 🧩 Variables Description

| Variable        | Description                     | Example          |
|-----------------|---------------------------------|------------------|
| `aws_region`    | AWS Region to deploy            | `ap-south-1`     |
| `aws_profile`   | AWS CLI profile name            | `default`        |
| `instance_type` | EC2 instance type               | `t2.micro`       |
| `stage`         | Environment (dev/prod)          | `dev`            |
| `key_name`      | Name of your EC2 key pair       | `terraform`      |
| `app_port`      | App running port                | `80`             |

---

## 🧠 Environment Config Files

### `dev.tfvars`
```hcl
aws_region    = "ap-south-1"
aws_profile   = "default"
instance_type = "t2.micro"
stage         = "dev"
key_name      = "terraform"
app_port      = 80
```

### `prod.tfvars`
```hcl
aws_region    = "ap-south-1"
aws_profile   = "default"
instance_type = "t3.micro"
stage         = "prod"
key_name      = "terraform"
app_port      = 80
```

---

## 🚀 Deployment Using Auto Environment Script

### 1️⃣ Make script executable
```bash
chmod +x deploy.sh
```

### 2️⃣ Run for Dev environment
```bash
./deploy.sh dev
```

### 3️⃣ Run for Prod environment
```bash
./deploy.sh prod
```

The script will:
- Initialize Terraform
- Pick the correct `.tfvars` file automatically
- Apply configuration and deploy app

---

## 🔍 Verify Deployment

After Terraform completes:
1. Go to **AWS Console → EC2 → Instances**
2. Copy the **Public IPv4 address**
3. Open in your browser:
   ```
   http://<public-ip>
   ```
