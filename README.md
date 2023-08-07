[![CI](https://github.com/joelee2012/skustomize/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/joelee2012/skustomize/actions/workflows/ci.yaml)
# skustomize

## About

skustomize is a wrapper for [kustomize](https://github.com/kubernetes-sigs/kustomize) that generate secrets with [secretGenerator](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/secretgenerator/) from different providers on the fly.

* Use [vals](https://github.com/helmfile/vals) to load values and secrets from providers
* Use skustomize in ArgoCD


## Installation

### prerequisite

* [kustomize](https://github.com/kubernetes-sigs/kustomize)
* [yq](https://github.com/mikefarah/yq) a lightweight and portable command-line YAML processor.
* [vals](https://github.com/helmfile/vals) is a tool for managing configuration values and secrets form various sources.

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


### install skustomize
    git clone https://github.com/joelee2012/skustomize/skustomize


## Usage

create [kustomization.yaml](./tests/kustomization.yaml)

    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    secretGenerator:
    - name: test-secret
        files:
        - key=age/key.txt
        - privateKey=ref+sops://secrets.yaml#/privateKey
        literals:
        - publicKey=ref+sops://secrets.yaml#/publicKey

create encrypted [secrets.yaml](./tests/secrets.yaml) files with sops 