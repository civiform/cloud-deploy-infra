# pgadmin

This directory contains files for creating the Docker image for the
CiviForm-customized pgadmin container. Namely, this image adds an init.py
script that writes the /pgadmin4/servers.json file. The image is hosted on
Docker hub and needs to be pushed there if any changes are made.
