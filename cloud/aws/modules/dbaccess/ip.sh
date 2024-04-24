#! /usr/bin/env bash

# DOC: Read the IP address of hosts needed for updating and installing packages on Ubuntu EC2 instances
# DOC: This script is expected to be called by the Terraform dbaccess module, which provides a JSON object
# DOC:   with a "region" key that contains the region of the EC2 instance. Each region contains a mirror
# DOC:   of archive.ubuntu.com that apt tries using first.

getip() {
  local host=$1
  # We do this instead of just dig +short in case it returns a CNAME. We only want A.
  dig $host +noall +answer | grep -E 'IN\s+A' | awk '{print $5}' | head -n 1
}

read -r input
region=$(echo $input | grep -o '"region": *"[^"]*"' | sed 's/"region": *"\([^"]*\)"/\1/')
# Perform DNS lookups of hosts needed for updating and installing
# packages on Ubuntu
security_ubuntu_com=$(getip security.ubuntu.com)
archive_ubuntu_com=$(getip archive.ubuntu.com)
region_ec2_archive_ubuntu_com=$(getip $region.ec2.archive.ubuntu.com)
apt_postgresql_org=$(getip apt.postgresql.org)

echo "{\"security_ubuntu_com\": \"${security_ubuntu_com}/32\", \"archive_ubuntu_com\": \"${archive_ubuntu_com}/32\", \"region_ec2_archive_ubuntu_com\": \"${region_ec2_archive_ubuntu_com}/32\", \"apt_postgresql_org\": \"${apt_postgresql_org}/32\"}"
