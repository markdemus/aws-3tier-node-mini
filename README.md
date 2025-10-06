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
