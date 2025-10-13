# AWS 3‑Tier Mini Project (Node.js + MySQL)

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
