terraform {
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}

provider "aws" { region = var.region }

# --- Security Groups ---
resource "aws_security_group" "alb" {
  name        = "alb-notes-sg"
  description = "ALB inbound 80"
  vpc_id      = var.vpc_id
  ingress { from_port = 80 to_port = 80 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "ec2" {
  name   = "ec2-notes-sg"
  vpc_id = var.vpc_id
  ingress { from_port = 3000 to_port = 3000 protocol = "tcp" security_groups = [aws_security_group.alb.id] }
  egress  { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

# --- Target Group + ALB ---
resource "aws_lb_target_group" "tg" {
  name     = "notes-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path = "/healthz" }
}

resource "aws_lb" "alb" {
  name               = "notes-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.tg.arn }
}

data "aws_ami" "al2023" {
  owners      = ["137112412989"] # Amazon
  most_recent = true
  filter { name = "name"; values = ["al2023-ami-*-x86_64"] }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "notes-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  user_data = base64encode(templatefile("${path.module}/../userdata.sh", {
    DB_HOST = var.db_host,
    DB_NAME = var.db_name,
    DB_USER = var.db_user,
    DB_PASS = var.db_pass
  }))

  vpc_security_group_ids = [aws_security_group.ec2.id]
}

resource "aws_autoscaling_group" "asg" {
  name                = "notes-asg"
  max_size            = 4
  min_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
}
