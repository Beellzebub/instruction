#!/bin/bash

yum update -y
amazon-linux-extras install epel -y
yum install nginx -y
yum install fail2ban -y
yum install git -y

systemctl enable nginx
systemctl start nginx
systemctl enable fail2ban
systemctl start fail2ban
systemctl enable firewalld
systemctl start firewalld

cat >> /etc/firewalld/services/nginx.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
<short>nginx</short>
<description>nginx with non-standard port</description>
<port protocol="tcp" port="80"/>
<port protocol="tcp" port="81"/>
</service>
EOF

firewall-cmd --reload
firewall-cmd --zone=public --add-service=nginx --permanent
firewall-cmd --reload

#sshd config for amzn
sed -i "s/$(grep -m 1 "PermitRootLogin" /etc/ssh/sshd_config)/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/$(grep -m 1 "PasswordAuthentication" /etc/ssh/sshd_config)/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart sshd

#sudoers config for amzn
sed -i "s/$(grep "# %wheel" /etc/sudoers)/%wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
sed -i "s/$(grep -m 1 "%wheel" /etc/sudoers)/# %wheel ALL=(ALL) ALL/" /etc/sudoers

adduser tutor-a
usermod -aG wheel tutor-a
mkdir /home/tutor-a/.ssh
touch /home/tutor-a/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChvBKAJbIt0H0O26DbZnu2I0kHG+OJBEvR0UkgqWwFb tutor-a" >> /home/tutor-a/.ssh/authorized_keys
chmod 700 /home/tutor-a/.ssh
chmod 600 /home/tutor-a/.ssh/authorized_keys
chown -R tutor-a:tutor-a /home/tutor-a/.ssh

repo_url="http://github.com/Beellzebub/page"
project_src="/home/ec2-user/project_src"

git clone "$repo_url" "$project_src"
mkdir -p /var/www/tutorial
cp "$project_src/html/index.html" "/var/www/tutorial/"
cp "$project_src/nginx/new_config" "/etc/nginx/conf.d/new.conf"
systemctl restart nginx

instance_ids="$(curl http://169.254.169.254/latest/meta-data/instance-id)"

instance_name="$(aws ec2 describe-instances \
--instance-ids "$instance_ids" \
--query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
--output text \
--region eu-central-1)"

account_id=$(aws sts get-caller-identity --query Account --output text)

hostnamectl set-hostname "$instance_name.$account_id.cirruscloud.click"

aws sts assume-role \
--role-arn "arn:aws:iam::272304640086:role/CloudEngJ2Ch06UpdateDNSZone327742888260" \
--role-session-name "Route53" \
--output text

set AWS_ACCESS_KEY_ID
set AWS_SECRET_ACCESS_KEY
set AWS_SESSION_TOKEN

zone_id="$(aws route53 list-hosted-zones \
--output text \
--region eu-central-1)"

aws route53 change-resource-records-sets \
--hosted-zone "$zone_id" \
--change-batch file://./json/change-resource-records-sets.json