#!/bin/bash
set -euxo pipefail

# Update & basics
yum update -y || apt-get update -y || true
# Install Node.js (Amazon Linux 2023 with dnf) fallback to Ubuntu apt
if command -v dnf >/dev/null 2>&1; then
  dnf module enable -y nodejs:18
  dnf install -y nodejs git
elif command -v yum >/dev/null 2>&1; then
  curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
  yum install -y nodejs git
else
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs git
fi

# App user & fetch repo
useradd -m app || true
su - app -c "git clone https://github.com/markdemus/aws-3tier-node-mini.git repo" || true
cd /home/app/repo/app
npm install

# Environment
cat >/home/app/env.sh <<EOF
export PORT=3000
export DB_HOST='${DB_HOST}'
export DB_NAME='${DB_NAME:-notesdb}'
export DB_USER='${DB_USER:-notesuser}'
export DB_PASS='${DB_PASS}'
EOF
chown app:app /home/app/env.sh
chmod 600 /home/app/env.sh

# systemd service
cat >/etc/systemd/system/notes.service <<'EOF'
[Unit]
Description=Node Notes App
After=network.target

[Service]
User=app
EnvironmentFile=/home/app/env.sh
WorkingDirectory=/home/app/repo/app
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now notes.service
