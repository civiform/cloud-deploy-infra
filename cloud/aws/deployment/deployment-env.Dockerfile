FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Install tool dependencies
RUN apt-get update && apt-get install -y \
    terraform \
    python3-pip \
    curl \
    unzip \
    python3.10-venv \
    default-jre \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/lists.d/* \
    && apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean

# Install AWS CLI
RUN	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip && ./aws/install

# Install Azure CLI
RUN	curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Docker-In-Docker
# Following the guide found here:
# https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/docker-in-docker.md
COPY library-scripts/*.sh /tmp/library-scripts/
ENV DOCKER_BUILDKIT=1
RUN apt-get update && /bin/bash /tmp/library-scripts/docker-in-docker-debian.sh
ENTRYPOINT ["/usr/local/share/docker-init.sh"]
VOLUME [ "/var/lib/docker" ]

# Start the a shell in the container, this image needs to be started with the following options
# --init --privileged -it
CMD ["bash"]

# Alternatively we could make the image sleep forever and then the user can connect into the
# running container.
# CMD ["sleep", "infinity"]
