#!/usr/bin/env bash
# Run on the Jenkins EC2 instance (Ubuntu 24.04): bash setup-jenkins-server.sh
set -euo pipefail
trap 'echo "ERROR: setup failed at line $LINENO: $BASH_COMMAND" >&2' ERR
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

sudo apt-get update
sudo apt-get install -y fontconfig openjdk-21-jre git curl wget

# Jenkins LTS apt repository; if the key fails, get the current one from https://www.jenkins.io/doc/book/installing/linux/
sudo install -m 0755 -d /etc/apt/keyrings
sudo wget -qO /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
sudo apt-get update
sudo apt-get install -y jenkins

bash "$SCRIPT_DIR/install-docker.sh"

# Lets pipelines run docker without sudo (note: docker group membership is root-equivalent).
sudo usermod -aG docker jenkins
sudo systemctl enable jenkins
sudo systemctl restart jenkins

PASSWORD_FILE=/var/lib/jenkins/secrets/initialAdminPassword
echo "Waiting for Jenkins to generate the initial admin password..."
for _ in $(seq 1 60); do
    sudo test -f "$PASSWORD_FILE" && break
    sleep 3
done

if sudo test -f "$PASSWORD_FILE"; then
    echo
    echo "Jenkins is running on port 8080. Initial admin password:"
    sudo cat "$PASSWORD_FILE"
else
    echo "Password file not found. Jenkins status and recent logs:" >&2
    sudo systemctl status jenkins --no-pager | head -n 15 >&2 || true
    sudo journalctl -u jenkins -n 30 --no-pager >&2 || true
    exit 1
fi
