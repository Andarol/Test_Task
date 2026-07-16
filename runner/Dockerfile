FROM ghcr.io/actions/actions-runner:2.335.1

USER root

ARG TERRAFORM_VERSION=1.10.5
ARG TERRAGRUNT_VERSION=1.0.4
ARG HELM_VERSION=3.17.3
ARG IMAGE_COMMIT=unknown

LABEL org.opencontainers.image.source="https://github.com/Andarol/Test_Task" \
      org.opencontainers.image.revision="${IMAGE_COMMIT}"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    ca-certificates curl docker.io git gnupg jq python3 sudo unzip \
  && rm -rf /var/lib/apt/lists/* \
  && install -d -m 0755 /usr/share/keyrings \
  && curl --fail --silent --show-error --location \
    https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl \
  && rm -rf /var/lib/apt/lists/* \
  && curl --fail --silent --show-error --location \
    "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    --output /tmp/terraform.zip \
  && unzip -q /tmp/terraform.zip -d /usr/local/bin \
  && rm -f /tmp/terraform.zip \
  && curl --fail --silent --show-error --location \
    "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
    --output /usr/local/bin/terragrunt \
  && chmod 0755 /usr/local/bin/terragrunt \
  && curl --fail --silent --show-error --location \
    "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /tmp \
  && install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm \
  && rm -rf /tmp/linux-amd64 \
  && usermod -aG docker runner

USER runner
