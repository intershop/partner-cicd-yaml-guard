
FROM python:3.10-slim

# System dependencies and tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    bash \
    ca-certificates \
    jq \
    && apt-get clean

# install yamllint with pip (works fine in Python environment)
RUN pip install yamllint

# kustomize setup
RUN curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash && \
    mv kustomize /usr/local/bin/

# kubeval setup
RUN curl -L "https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz" | tar xz && \
    mv kubeval /usr/local/bin/ && \
    chmod +x /usr/local/bin/kustomize /usr/local/bin/kubeval

# Copy validate_kustomize.sh script and make it executable
COPY scripts/validate_kustomize.sh /usr/local/bin/validate_kustomize.sh
RUN chmod +x /usr/local/bin/validate_kustomize.sh

# work directory
WORKDIR /src

# Entry point left blank; direct commands can be executed
# You can also add ENTRYPOINT [‘bash’] if you want
