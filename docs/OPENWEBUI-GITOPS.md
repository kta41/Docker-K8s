# Activar la sincronización GitOps de Open WebUI

La Application `openwebui-config` apunta a
`https://github.com/kta41/openwebui-ai-config.git`. El repositorio contiene
un `ConfigMap` generado por Kustomize y un Job hook de Argo CD. El Job llama
al Service interno `open-webui-service`, por lo que no necesita el Ingress ni
el certificado CA.

## 1. Crear el Secret de la API key

Desde `/home/Kta41/Docker-K8s`, carga el `.env` local y crea el Secret sin
imprimir la clave:

```bash
cd /home/Kta41/Docker-K8s
set -a
source .env
set +a

kubectl create secret generic openwebui-sync-auth \
  --namespace default \
  --from-literal=api-key="$OPENWEBUI_API_KEY" \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

## 2. Registrar el repositorio privado en Argo CD

Usa un Fine-grained Personal Access Token de GitHub con acceso **Contents:
Read-only** únicamente al repositorio `kta41/openwebui-ai-config`.

```bash
read -rsp "GitHub token de solo lectura: " GITHUB_READ_TOKEN
echo

kubectl create secret generic repo-openwebui-ai-config \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/kta41/openwebui-ai-config.git \
  --from-literal=username=kta41 \
  --from-literal=password="$GITHUB_READ_TOKEN" \
  --dry-run=client \
  -o yaml |
  kubectl label --local -f - \
    argocd.argoproj.io/secret-type=repository \
    -o yaml |
  kubectl apply -f -

unset GITHUB_READ_TOKEN
```

Comprueba que Argo CD reconoce el repositorio:

```bash
kubectl get secret repo-openwebui-ai-config -n argocd
kubectl logs -n argocd deployment/argocd-repo-server --tail=100
```

## 3. Crear la Application

La Application ya está en
`Proxygpt/argocd/openwebui-config-app.yaml`. Aplícala una vez:

```bash
kubectl apply -f Proxygpt/argocd/openwebui-config-app.yaml
```

Comprueba el estado:

```bash
kubectl get application openwebui-config -n argocd
kubectl get jobs,pods -l app=openwebui-model-sync
kubectl logs -n default job/openwebui-model-sync
```

## 4. Flujo posterior

Cada cambio en `models/*.json` debe incluir el archivo en la lista `files` de
`kustomization.yaml`, y después se publica normalmente:

```bash
cd /home/Kta41/openwebui-ai-config
git add models kustomization.yaml
git commit -m "Update Open WebUI model"
git push
```

Argo CD detecta `main`, cambia el hash del ConfigMap y ejecuta de nuevo el
Job hook. El Job sincroniza exactamente la lista de modelos. Un modelo
ausente del payload se elimina de Open WebUI.
