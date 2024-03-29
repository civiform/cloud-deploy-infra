FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    terraform \
    direnv \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/lists.d/* \
    && apt-get autoremove \
    && apt-get clean \
    && apt-get autoclean

# Set up direnv hook
RUN echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
RUN echo 'eval "$(direnv hook bash)"' >> ~/.bash_profile

# Install pip and yapf
RUN apt-get update && apt-get install -y python3-pip
RUN pip install yapf
