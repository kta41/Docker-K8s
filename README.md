# Docker-K8s: AI Stack GitOps

Infraestructura GitOps para desplegar y operar un stack de IA sobre
Kubernetes:

- **Open WebUI**: interfaz, modelos personalizados, system prompts, Tools y
  Knowledge Bases.
- **LiteLLM**: gateway compatible con OpenAI, routing y catálogo de modelos.
- **PostgreSQL**: persistencia de LiteLLM y Open WebUI.
- **Argo CD**: reconciliación de infraestructura y configuración declarativa.
- **Kustomize**: composición de manifiestos por entorno.

El repositorio de configuración funcional de Open WebUI está separado en:

[`kta41/openwebui-ai-config`](https://github.com/kta41/openwebui-ai-config)

## Arquitectura de repositorios

```text
Docker-K8s
├── Kubernetes, Argo CD, Kustomize y Secrets
├── LiteLLM config.yaml
└── Application de Argo CD para Open WebUI

openwebui-ai-config
├── models/*.json
├── prompts/*.md
├── knowledge/*.md
├── kustomization.yaml
└── Sync Hook Job
```

## Flujo GitOps de Open WebUI

```text
git push openwebui-ai-config
        |
        v
Argo CD detecta main
        |
        v
Kustomize genera ConfigMap con hash
        |
        v
Argo CD ejecuta Sync Hook Job
        |
        v
Job usa el Secret openwebui-sync-auth
        |
        v
POST /api/v1/models/sync
        |
        v
Open WebUI actualiza los modelos personalizados
```

El Job utiliza el Service interno:

```text
http://open-webui-service.default.svc.cluster.local:8080
```

Por tanto, la sincronización GitOps no depende del certificado CA del Ingress.
El CA sólo es necesario para acceder desde la máquina local a:

```text
https://ia.kta41.local
```

## Estructura principal

```text
.
├── Infrastructure/
│   ├── ArgoCD/
│   ├── CertManager/
│   ├── Gitea/
│   └── Traefik/
├── Proxygpt/
│   ├── argocd/
│   ├── litellm/
│   ├── openwebui/
│   └── postgres/
├── docs/
├── scripts/
├── .env.example
└── README.md
```

## Despliegue de infraestructura

Requisitos:

- Kubernetes/K3s operativo.
- `kubectl` configurado.
- Argo CD instalado.
- cert-manager y CA interno disponibles.
- Ollama accesible en `http://127.0.0.1:11435`.

Instalación inicial:

```bash
cp .env.example .env
chmod 700 scripts/install.sh
scripts/install.sh --env-file .env
```

El archivo `.env` contiene secretos y nunca debe publicarse.

Validación de manifiestos:

```bash
kubectl kustomize Proxygpt/postgres/base >/dev/null
kubectl kustomize Proxygpt/litellm/overlays/prod >/dev/null
kubectl kustomize Proxygpt/openwebui/overlays/prod >/dev/null
```

## Activar Open WebUI GitOps

La Application está en:

[`Proxygpt/argocd/openwebui-config-app.yaml`](Proxygpt/argocd/openwebui-config-app.yaml)

### 1. Crear el Secret de la API key

Con la clave en `.env`:

```bash
set -a
source .env
set +a

kubectl create secret generic openwebui-sync-auth \
  --namespace default \
  --from-literal=api-key="$OPENWEBUI_API_KEY" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

unset OPENWEBUI_API_KEY
```

### 2. Registrar el repositorio privado en Argo CD

Crear un Fine-grained Personal Access Token de GitHub limitado a
`kta41/openwebui-ai-config` con `Contents: Read-only`.

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

### 3. Aplicar la Application

```bash
kubectl apply -f Proxygpt/argocd/openwebui-config-app.yaml
```

Comprobar:

```bash
kubectl get application openwebui-config -n argocd
kubectl get jobs,pods -n default -l app=openwebui-model-sync
```

El estado esperado es:

```text
Synced
Healthy
Succeeded
```

## Modificar un modelo

Edita el repositorio externo:

```bash
cd ../openwebui-ai-config
nano models/qwen3-14b-assistant.json
```

Si creas un JSON nuevo, añádelo explícitamente a
`kustomization.yaml`.

Valida y publica:

```bash
python3 -m json.tool models/qwen3-14b-assistant.json >/dev/null
kubectl kustomize . >/dev/null
git add models/ kustomization.yaml
git commit -m "Update Open WebUI model"
git push
```

Argo CD detectará el commit y ejecutará el Job automáticamente.

## LiteLLM

La fuente de verdad de LiteLLM es:

[`Proxygpt/litellm/base/config.yaml`](Proxygpt/litellm/base/config.yaml)

Aquí se mantienen:

- Alias de modelos.
- Proveedores.
- `api_base`.
- Routing y parámetros del gateway.
- Configuración declarativa del proxy.

No se deben gestionar los mismos modelos simultáneamente desde
`config.yaml` y la base de datos de LiteLLM sin una política explícita.

## Certificado CA local

El CA raíz está en el Secret `kta-root-ca` del namespace `cert-manager`.
Para instalarlo en Debian/Ubuntu:

```bash
kubectl get secret kta-root-ca \
  -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' |
  base64 -d |
  sudo tee /usr/local/share/ca-certificates/kta-root-ca.crt >/dev/null

sudo update-ca-certificates
```

Después:

```bash
curl https://ia.kta41.local/health
```

debe funcionar sin `-k`.

## Documentación relacionada

- [Guía completa de instalación](docs/INSTALL.md)
- [Contrato de configuración GitOps](docs/CONFIG-GITOPS.md)
- [Configuración GitOps de Open WebUI](docs/OPENWEBUI-GITOPS.md)
- [Repositorio de configuración Open WebUI](https://github.com/kta41/openwebui-ai-config)
- [Documentación de Open WebUI](https://docs.openwebui.com/)
- [Documentación de LiteLLM](https://docs.litellm.ai/)

## Seguridad

Nunca publicar:

- `.env`.
- API keys.
- Tokens de GitHub.
- `LITELLM_MASTER_KEY`.
- `LITELLM_SALT_KEY`.
- Claves de proveedores.
- JWT, cookies o sesiones.
- `tls.key`.
- Dumps de PostgreSQL.

Las Functions y Tools de Open WebUI ejecutan código en el servidor y deben
revisarse como código privilegiado antes de desplegarse.
