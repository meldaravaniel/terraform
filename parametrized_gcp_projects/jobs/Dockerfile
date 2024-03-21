FROM ubuntu:jammy-${your fave tag}

ARG GCLOUD_VERSION

# We need curl for the hcql install.sh...
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

 # Install Google Cloud SDK, kubectl, and skaffold
RUN wget -q -O- https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-x86_64.tar.gz \
    | tar -xz -C / \
    && /google-cloud-sdk/install.sh -q

# Install helm
RUN wget -q -O- https://get.helm.sh/helm-v${your fave helm version}-linux-amd64.tar.gz \
    | tar -xz -C / \
    && mv linux-amd64/helm /usr/local/bin/helm
 
# Install gcrane for copying images from DockerHub to GAR
RUN wget -q -O- https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/gcrane

ENV PATH /google-cloud-sdk/bin:${PATH}
