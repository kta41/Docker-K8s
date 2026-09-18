# Enable Open WebUI GitOps Synchronization

The `openwebui-config` Application points to
`https://github.com/kta41/openwebui-ai-config.git`. The repository contains a
Kustomize-generated `ConfigMap` and an Argo CD hook Job. The Job calls the
internal `open-webui-service`, so it does not need the Ingress or CA certificate.

## 1. Create the API Key Secret

From `/home/Kta41/ProxyGPT`, load the local `.env` and create the Secret without
printing the key:

```bash
cd /home/Kta41/ProxyGPT
set -a
source .env
set +a

kubectl create secret generic openwebui-sync-auth \
  --namespace default \
  --from-literal=api-key="$OPENWEBUI_API_KEY" \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

## 2. Register the Private Repository in Argo CD

Use a GitHub fine-grained Personal Access Token with **Contents: Read-only**
access limited to `kta41/openwebui-ai-config`.

```bash
read -rsp "Read-only GitHub token: " GITHUB_READ_TOKEN
echo

kubectl create secret generic repo-openwebui-ai-config \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/kta41/openwebui-ai-config.git \
  --from-literal=username=kta41 \
  --from-literal=****** \
  --dry-run=client \
  -o yaml |
  kubectl label --local -f - \
    argocd.argoproj.io/secret-type=repository \
    -o yaml |
  kubectl apply -f -

unset GITHUB_READ_TOKEN
```

Check that Argo CD recognizes the repository:

```bash
kubectl get secret repo-openwebui-ai-config -n argocd
kubectl logs -n argocd deployment/argocd-repo-server --tail=100
```

## 3. Create the Application

The Application is already in
`deploy/argocd/openwebui-config-app.yaml`. Apply it once:

```bash
kubectl apply -f deploy/argocd/openwebui-config-app.yaml
```

Check its status:

```bash
kubectl get application openwebui-config -n argocd
kubectl get jobs,pods -l app=openwebui-model-sync
kubectl logs -n default job/openwebui-model-sync
```

## 4. Subsequent Workflow

Every change to `models/*.json` must add the file to the `files` list in
`kustomization.yaml`, then publish it normally:

```bash
cd /home/Kta41/openwebui-ai-config
git add models kustomization.yaml
git commit -m "Update Open WebUI model"
git push
```

Argo CD detects `main`, changes the ConfigMap hash, and runs the hook Job again.
The Job synchronizes exactly the model list. A model absent from the payload is
removed from Open WebUI.
