#---------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

ARG PYTHON_VERSION="3.6.4"

FROM python:${PYTHON_VERSION}-alpine3.7

ARG CLI_VERSION

# Metadata as defined at http://label-schema.org
ARG BUILD_DATE

LABEL maintainer="Microsoft" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.vendor="Microsoft" \
      org.label-schema.name="Azure CLI" \
      org.label-schema.version=$CLI_VERSION \
      org.label-schema.license="MIT" \
      org.label-schema.description="The Azure CLI is used for all Resource Manager deployments in Azure." \
      org.label-schema.url="https://docs.microsoft.com/en-us/cli/azure/overview" \
      org.label-schema.usage="https://docs.microsoft.com/en-us/cli/azure/install-az-cli2#docker" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/Azure/azure-cli.git" \
      org.label-schema.docker.cmd="docker run -v \${HOME}/.azure:/root/.azure -it microsoft/azure-cli:$CLI_VERSION"

# bash gcc make openssl-dev libffi-dev musl-dev - dependencies required for CLI
# openssh - included for ssh-keygen
# ca-certificates

# curl - required for installing jp
# jq - we include jq as a useful tool
# pip wheel - required for CLI packaging
# jmespath-terminal - we include jpterm as a useful tool
# libintl and icu-libs - required by azure devops artifact (az extension add --name azure-devops)
RUN apk add --no-cache bash openssh ca-certificates jq curl openssl git zip \
 && apk add --no-cache --virtual .build-deps gcc make openssl-dev libffi-dev musl-dev linux-headers \
 && apk add --no-cache libintl icu-libs \
 && update-ca-certificates

ARG JP_VERSION="0.1.3"

RUN curl -L https://github.com/jmespath/jp/releases/download/${JP_VERSION}/jp-linux-amd64 -o /usr/local/bin/jp \
 && chmod +x /usr/local/bin/jp \
 && pip install --no-cache-dir --upgrade jmespath-terminal

WORKDIR azure-cli
COPY . /azure-cli

# 1. Build packages and store in tmp dir
# 2. Install the cli and the other command modules that weren't included
# 3. Temporary fix - install azure-nspkg to remove import of pkg_resources in azure/__init__.py (to improve performance)
RUN ./scripts/install_full.sh \
 && cat /azure-cli/az.completion > ~/.bashrc \
 && runDeps="$( \
    scanelf --needed --nobanner --recursive /usr/local \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | sort -u \
        | xargs -r apk info --installed \
        | sort -u \
    )" \
 && apk add --virtual .rundeps $runDeps

WORKDIR /

# Remove CLI source code from the final image and normalize line endings.
RUN rm -rf ./azure-cli && \
    dos2unix /root/.bashrc /usr/local/bin/az

CMD bash
