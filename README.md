# kube-state

This repository describes the desired state of the ShopHub platform's Kubernetes cluster(s), in a GitOps style. It contains no application code and no Helm templates. It only holds declarative references to which Helm charts, from the `helm-charts` repository, should be installed, at which versions, and with which `values.yaml` overrides. ArgoCD watches this repository and automatically syncs the actual state of the cluster with what is described here.

## Structure

`clusters/local/cluster.yaml` holds metadata about the local development cluster, including the k3d provider and the `127.0.0.1.nip.io` ingress domain; this file is what an ArgoCD ApplicationSet uses as its source for generating an Application resource for every installation. Each `clusters/local/<installation>/helm.yaml` file is the ArgoCD Application definition for that installation, specifying which chart from `helm-charts` to use in OCI format, which version through `targetRevision`, and the sync policy (automated, prune, self heal). Each `clusters/local/<installation>/values.yaml` file holds the Helm value overrides specific to that installation and environment. `scripts/cluster-up.sh` is a script for bringing up the local k3d cluster.

The installations currently defined under `clusters/local/` are shop-operator, which deploys the Kubernetes operator that manages the Shop, DiscordChannel, and Wallet custom resource definitions; shophub, which deploys the ShopHub back end, front end, and PostgreSQL database, with overrides for the image repository and tag, port, JWT secret placeholder, ingress host, and PostgreSQL volume size; and shophub-discord, which deploys cluster level Discord alerting through a PrometheusRule and AlertManager integration, reusing the same shop-operator chart but activating only its Discord webhook component, installed into the monitoring namespace.

## Role in the architecture

This repository is the last mile of the DevOps flow. The `helm-charts` repository defines how something is installed, this repository defines what should be installed and where in a given cluster, and ArgoCD, the GitOps controller, reads this repository and applies any differences to the cluster automatically through `syncPolicy.automated` with prune and selfHeal enabled. Changing a chart version or its configuration is done exclusively by editing files in this repository; there is no manual `helm install` or `kubectl apply` in production.

## Technical stack

GitOps is implemented through ArgoCD using `argoproj.io/v1alpha1` Application resources, with charts pulled as OCI artifacts from the `helm-charts` registry. k3d is used as the local Kubernetes distribution for the development environment. Continuous integration runs through `.github/workflows/ci.yml` with Conventional Commits enforced by `commitlint.config.cjs`, matching the rest of the platform's repositories.
