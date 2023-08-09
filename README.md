[![CI](https://github.com/joelee2012/skustomize/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/joelee2012/skustomize/actions/workflows/ci.yaml)
[![codecov](https://codecov.io/gh/joelee2012/skustomize/branch/main/graph/badge.svg?token=HEKUTJ7AH2)](https://codecov.io/gh/joelee2012/skustomize)
# skustomize

## About

skustomize is a [kustomize](https://github.com/kubernetes-sigs/kustomize) wrapper that make [secretGenerator](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/secretgenerator/) generate secrets from encrypted resources on the fly. 

## Installation

### Prerequisites

* [kustomize](https://github.com/kubernetes-sigs/kustomize) is a tool to customize Kubernetes objects
* [vals](https://github.com/helmfile/vals) is a tool for managing configuration values and secrets form various sources.
* [yq](https://github.com/mikefarah/yq) is a lightweight and portable command-line YAML processor.

    It supports various backends:

    * [Vault](https://github.com/helmfile/vals#vault)
    * [AWS SSM Parameter Store](https://github.com/helmfile/vals#aws-ssm-parameter-store)
    * [AWS Secrets Manager](https://github.com/helmfile/vals#aws-secrets-manager)
    * [AWS S3](https://github.com/helmfile/vals#aws-s3)
    * [GCP Secrets Manager](https://github.com/helmfile/vals#gcp-secrets-manager)
    * [Azure Key Vault](https://github.com/helmfile/vals#azure-key-vault)
    * [SOPS-encrypted files](https://github.com/helmfile/vals#sops)
    * [Terraform State](https://github.com/helmfile/vals#terraform-tfstate)
    * [Plain File](https://github.com/helmfile/vals#file)


### Install skustomize

```sh
curl -Lvo /usr/local/bin/skustomize https://raw.githubusercontent.com/joelee2012/skustomize/main/skustomize
chmod +x /usr/local/bin/skustomize
# optional
echo 'alias kustomize=skustomize' >> ~/.bashrc
source ~/.bashrc
```


## Usage

Check [tests](./tests) as example

- Create [kustomization.yaml](./tests/kustomization.yaml)

    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    secretGenerator:
    - name: test-secret
        files:
        - key=age/key.txt
        - privateKey=ref+sops://secrets.yaml#/privateKey
        literals:
        - publicKey=ref+sops://secrets.yaml#/publicKey
    configMapGenerator:
    - name: my-java-server-env-vars
        literals:
        - JAVA_HOME=/opt/java/jdk
        - JAVA_TOOL_OPTIONS=-agentlib:hprof
    ```

- Create sops encrypted [secrets.yaml](./tests/secrets.yaml) files with content of [ssh](./tests/ssh/)

- Run `skustomize build tests`

    ```sh
    export SOPS_AGE_KEY_FILE=$PWD/tests/age/key.txt
    skustomize build tests
    ```

## ArgoCD support

### Custom Docker Image

```dockerfile
ARG ARGOCD_VERSION="v2.8.0"
FROM quay.io/argoproj/argocd:$ARGOCD_VERSION
ARG SOPS_VERSION=3.7.3
ARG VALS_VERSION=0.25.0
ARG YQ_VERSION=4.34.2

ENV KUSTOMIZE_BIN=/usr/local/bin/kustomize

USER root

RUN apt-get update && apt-get install -y \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -fsSL https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux \
    -o /usr/local/bin/sops && chmod +x /usr/local/bin/sops \
    && curl -fsSL https://github.com/helmfile/vals/releases/download/v${VALS_VERSION}/vals_${VALS_VERSION}_linux_amd64.tar.gz \
    | tar xzf - -C /usr/local/bin/ vals && chmod +x /usr/local/bin/vals \
    && curl -fsSLo /usr/local/sbin/kustomize https://raw.githubusercontent.com/joelee2012/skustomize/main/skustomize \
    && chmod +x /usr/local/sbin/kustomize \
    && curl -fsSL https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

USER $ARGOCD_USER_ID
```