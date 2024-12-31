FROM google/cloud-sdk:stable

RUN apt-get update
RUN apt-get install curl gnupg --yes

# Python3
ENV PATH="$PATH:/usr/lib/google-cloud-sdk/platform/bundledpythonunix/bin/"
RUN python3 --version
RUN pip3 install pyyaml

# SQL Proxy
RUN curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.2/cloud-sql-proxy.linux.amd64
RUN chmod +x cloud-sql-proxy
RUN mv cloud-sql-proxy /usr/local/bin/cloud-sql-proxy
RUN cloud-sql-proxy -v

# OpenTofu
RUN curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
RUN chmod +x install-opentofu.sh
RUN ./install-opentofu.sh --install-method deb
RUN rm -f install-opentofu.sh
RUN tofu -v

# Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
RUN curl -LO https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
RUN echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
RUN chmod +x kubectl
RUN mv kubectl /usr/local/bin/
RUN kubectl version --client

# Helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
RUN apt-get install apt-transport-https --yes
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
RUN apt-get update
RUN apt-get install helm --yes
RUN helm version

WORKDIR /home

COPY civ           /home
COPY cli           /home/cli
COPY control_plane /home/control_plane
COPY data_plane    /home/data_plane

ENTRYPOINT ["/home/civ"]
