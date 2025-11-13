# AWS 3‑Tier Mini Project (Node.js + MySQL)

PHASE 1:
- **ALB → EC2 Auto Scaling (Node.js/Express) → RDS MySQL**
- Security Groups with least‑privilege edges
- Health checks, simple CRUD endpoint, user data bootstrap

## Architecture (high‑level)
User → **ALB (HTTP 80)** → **EC2 in ASG (port 3000)** → **RDS MySQL (3306)**

## App Endpoints
- `GET /healthz` → 200 ok
- `GET /` → Hello banner
- `GET /notes` → list notes
- `POST /notes` JSON: `{ "text": "..." }` → create note

# AWS 3-Tier Node.js Notes App

**Stack**: ALB → ASG/EC2 (Node.js) → RDS MySQL  
**Infra**: Terraform (AWS provider v5)

## One-time setup
- Create RDS MySQL (db.t3.micro), note endpoint/user/pass
- Get default VPC + two public + two private subnets

## Deploy
```bash
cd infra/terraform
terraform init
terraform apply \
  -var 'region=us-east-2' \
  -var 'vpc_id=...' \
  -var 'public_subnets=["subnet-...","subnet-..."]' \
  -var 'private_subnets=["subnet-...","subnet-..."]' \
  -var 'db_host=notes-db.xxxx.us-east-2.rds.amazonaws.com' \
  -var 'db_user=notesuser' \
  -var 'db_pass=***' \
  -var 'db_name=notesdb'

## Cost & cleanup
- This stack runs an ALB, 2× t3.micro, and RDS t3.micro:  
  ```bash
  cd infra/terraform
  terraform destroy


flowchart LR
  subgraph Internet
    U[User]
  end

  U -->|HTTP :80| ALB[Application Load Balancer]

  subgraph VPC["VPC (us-east-2)"]
    direction LR

    subgraph PublicSubnets["Public Subnets"]
      ALB
    end

    subgraph PrivateSubnets["Private Subnets (App Tier)"]
      ASG[(Auto Scaling Group)]
      EC2A[EC2 Node.js App]
      EC2B[EC2 Node.js App]
      ASG --- EC2A
      ASG --- EC2B
    end

    subgraph DBSubnets["DB Subnets (RDS)"]
      RDS[(RDS MySQL)]
    end
  end

  ALB -->|HTTP :3000 (Target Group)| EC2A
  ALB -->|HTTP :3000 (Target Group)| EC2B

  EC2A -->|MySQL :3306| RDS
  EC2B -->|MySQL :3306| RDS

  %% Security Groups
  classDef sg fill:
  #eef,stroke:
  #88a,stroke-width:1px,color:
  #223,font-size:12px;
  SG_ALB[[SG: ALB<br/>in: 80 from 0.0.0.0/0<br/>out: all]]:::sg
  SG_EC2[[SG: EC2<br/>in: 3000 from ALB SG<br/>out: all]]:::sg
  SG_RDS[[SG: RDS<br/>in: 3306 from EC2 SG]]:::sg

  SG_ALB --- ALB
  SG_EC2 --- EC2A
  SG_EC2 --- EC2B
  SG_RDS --- RDS

  %% IAM / SSM (optional)
  classDef opt fill:
  #f8fff2,stroke:
  #8bbf56,stroke-width:1px,color:
  #223,font-size:12px,stroke-dasharray: 4 2;
  SSM[EC2 IAM Role: AmazonSSMManagedInstanceCore]:::opt
  SSM --- EC2A
  SSM --- EC2B

| Concept                                | What I Did                                                                                               | How It Maps to Stéphane Maarek’s SAA Course                  |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| **IAM Basics**                         | Created an IAM role and instance profile for EC2 to access SSM and other AWS services.                     | *Section 5–6: IAM Users, Roles, and Policies*                |
| **EC2 Fundamentals**                   | Used EC2 Launch Templates, key pairs, user data, and systemd startup scripts.                              | *Section 7: EC2, Security Groups, User Data, Elastic IPs*    |
| **VPC & Networking**                   | Referenced your default VPC, public/private subnets, and proper security group chaining (ALB → EC2 → RDS). | *Section 9: VPC, Subnets, Security Groups, NACLs*            |
| **Elastic Load Balancing (ALB)**       | Created an Application Load Balancer and Target Group, configured health checks, and tested via DNS.       | *Section 10: Elastic Load Balancers (ALB, NLB)*              |
| **Auto Scaling Groups (ASG)**          | Built an ASG with multiple EC2s connected to your ALB, scaling from 2–4 instances.                         | *Section 10: Auto Scaling and Elasticity Concepts*           |
| **RDS Basics**                         | Created a MySQL RDS instance, set up connectivity, and secured it via SGs.                                 | *Section 11 (coming soon in course): RDS and Aurora Basics*  |
| **Terraform Infrastructure as Code**   | Defined and deployed all infrastructure using Terraform.                                                   | *Section 13 (later in course): Infrastructure as Code (IaC)* |
| **SSM Session Manager**                | Used Session Manager to securely access EC2 without SSH keys.                                              | *Section 7 & 9: EC2 Access Methods & SSM Overview*           |
| **Networking Security Best Practices** | Restricted inbound rules by chaining SGs instead of using `0.0.0.0/0` everywhere.                          | *Section 9: VPC Security Groups, Best Practices*             |


PHASE 2:
graph TD
  A[User] -->|HTTPS| B[CloudFront Distribution]
  B -->|Static Assets| C[S3 Static Website]
  B -->|API Calls| D[Application Load Balancer]
  D --> E[Auto Scaling Group (EC2 Notes App)]
  E --> F[(RDS MySQL Database)]
  E --> G[SQS Queue (Async Jobs)]
  H[IAM Roles & Policies] --> E

S3 Bucket for Static site:
resource "aws_s3_bucket" "static_site" {
  bucket = "notes-static-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })
}

CloudFront Distribution for S3 Bucket:
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "static-oac"
  description                       = "OAC for S3 static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "static_cf" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id   = "s3-static-site"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "s3-static-site"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  price_class = "PriceClass_100" # FREE tier friendly

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.static_cf.domain_name
}


SQS Decouple Layer:
resource "aws_sqs_queue" "notes_queue" {
  name = "notes-async-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
}

output "sqs_queue_url" {
  value = aws_sqs_queue.notes_queue.id
}


| Section | AWS Focus                       | What I Implemented                      |
| ------- | ------------------------------- | --------------------------------------- |
| 11      | High Availability & Scalability | Documented HA design                    |
| 12–13   | S3 Storage & Lifecycle          | Versioned bucket for screenshots        |
| 14      | S3 Security                     | IAM + Bucket Policies + Pre-Signed URLs |
| 15      | CloudFront CDN                  | HTTPS Distribution for Static Assets    |
| 16      | EBS & Snapshots                 | Snapshot and restore demo               |
| 17      | SQS/SNS Messaging               | Async queue integration concept         |
