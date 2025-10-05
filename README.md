# AWS 3‑Tier Mini Project (Node.js + MySQL)

A small, interview‑ready 3‑tier app on AWS:

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

## Local Run
```bash
cd app
cp .env.sample .env   # fill DB_* if you have local MySQL
npm install
node server.js
```

## AWS Deploy (quick path)
1. Create **RDS MySQL** (db.t3.micro, single‑AZ). Save endpoint, user, password.
2. Create Security Groups:
   - `alb-sg`: inbound 80 from 0.0.0.0/0
   - `ec2-sg`: inbound 3000 from `alb-sg`
   - `rds-sg`: inbound 3306 from `ec2-sg`
3. (Terraform optional) Fill `infra/terraform/variables.tf` values and run:
   ```bash
   cd infra/terraform
   terraform init
   terraform apply -var vpc_id="vpc-xxxx"      -var 'public_subnets=["subnet-a","subnet-b"]'      -var 'private_subnets=["subnet-c","subnet-d"]'      -var db_host="your-rds-endpoint.rds.amazonaws.com"      -var db_user="notesuser"      -var db_pass="changeme"      -var db_name="notesdb"
   ```
4. The **Launch Template user data** (see `infra/userdata.sh`) installs Node, pulls this repo, sets env, and starts the service.
5. Open the **ALB DNS name** in your browser and hit `/healthz`, `/notes`.

## Costs
Keep it to a few dollars if you stop when not in use. Use `db.t3.micro`, 20GB gp3, turn off when done. Set an AWS Budget alert.

## Portfolio Tips
- Add a diagram (`diagrams/architecture.drawio`) using AWS icons.
- In the README, explain trade‑offs (EC2 vs Elastic Beanstalk/ECS; MySQL vs DynamoDB).
- Add “Future work”: HTTPS (ACM), Secrets Manager, CI/CD (CodePipeline or GitHub Actions).
