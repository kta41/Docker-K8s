# Installation

The installer provisions the stack's Kubernetes Secrets, configures the
selected domains in the tracked overlays, and submits the existing Argo CD
`Application` manifests. It never edits or deletes databases, PVCs, or
existing Secrets unless Kubernetes applies the explicitly named Secret.

## Prerequisites

- A reachable Kubernetes cluster and a configured `kubectl` context.
- Argo CD installed in the `argocd` namespace.
- Traefik and cert-manager installed (the installer warns if either is
  reported missing; it does not install third-party controllers).

## Usage

Copy the example file to a local, ignored file and fill in its values:

```bash
cp .env.example .env
chmod 700 scripts/install.sh
scripts/install.sh --env-file .env
```

Without `--env-file`, the installer prompts for every value. It first asks
whether Argo CD, Traefik, and cert-manager already exist, then validates
`kubectl`, asks for domains, credentials, and model-provider keys, and applies
Secrets with `kubectl apply`. Secret values are never written to this
repository. The provider choice can be `none`, `openai`, `anthropic`, or
`both`.

`.env` is local configuration containing secrets and must remain untracked;
only `.env.example` belongs in Git. The installer updates the tracked
LiteLLM/Open WebUI overlays with the selected domains, validates them with
Kustomize, and asks whether to commit and push those domain-only changes.
Secrets are never committed. If you answer `no`, commit and push the changed
overlays manually before syncing Argo CD.

`LITELLM_SALT_KEY` must be generated once and kept unchanged for the lifetime
of the LiteLLM database. Changing it can make provider credentials stored in
PostgreSQL unreadable.

## Rendering checks

Render the overlays before applying changes:

```bash
kubectl kustomize Proxygpt/postgres/base >/dev/null
kubectl kustomize Proxygpt/litellm/overlays/prod >/dev/null
kubectl kustomize Proxygpt/openwebui/overlays/prod >/dev/null
```
