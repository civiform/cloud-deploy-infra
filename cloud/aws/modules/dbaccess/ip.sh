#! /usr/bin/env bash

# DOC: Read the IP address of hosts needed for updating and installing packages on Ubuntu EC2 instances
# DOC: This script is expected to be called by the Terraform dbaccess module, which provides a JSON object
# DOC:   with a "region" key that contains the region of the EC2 instance. Each region contains a mirror
# DOC:   of archive.ubuntu.com that apt tries using first.

read -r input
region=$(echo $input | grep -o '"region": *"[^"]*"' | sed 's/"region": *"\([^"]*\)"/\1/')
# Perform DNS lookups of hosts needed for updating and installing
# packages on Ubuntu
security_ubuntu_com=$(dig +short security.ubuntu.com | head -n 1)
archive_ubuntu_com=$(dig +short archive.ubuntu.com | head -n 1)
region_ec2_archive_ubuntu_com=$(dig +short $region.ec2.archive.ubuntu.com | head -n 1)

echo "{\"security_ubuntu_com\": \"${security_ubuntu_com}/32\", \"archive_ubuntu_com\": \"${archive_ubuntu_com}/32\", \"region_ec2_archive_ubuntu_com\": \"${region_ec2_archive_ubuntu_com}/32\"}"
