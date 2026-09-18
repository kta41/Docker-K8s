#  AI-Stack GitOps: LiteLLM + Open WebUI + Postgres

Este repositorio contiene la arquitectura completa para desplegar un stack de Inteligencia Artificial privado y escalable en **Kubernetes**. La gestión de la infraestructura se realiza mediante un modelo **GitOps** utilizando **ArgoCD** y **Kustomize**.

![Status](https://img.shields.io/badge/Status-Production--Ready-green)
![K8s](https://img.shields.io/badge/Kubernetes-K3s-blue)
![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange)

## 🏗️ Arquitectura del Sistema

![Estado de ArgoCD](./img/dashboard.png)

El stack se compone de tres capas principales diseñadas para trabajar en armonía dentro del clúster:

1.  **Interfaz de Usuario (Frontend):** [Open WebUI](https://github.com/open-webui/open-webui), una interfaz intuitiva para interactuar con LLMs.
2.  **Orquestador de Modelos (Middleware):** [LiteLLM](https://github.com/BerriAI/litellm), que actúa como proxy para gestionar múltiples modelos y proveedores.
3.  **Persistencia (Backend):** Base de datos **PostgreSQL** para almacenar chats, usuarios y configuraciones.

LiteLLM se publica mediante Traefik en `https://litellm.kta41.local` y expone
dos modelos locales de Ollama (`qwen3-14b` y `qwen3-30b`), además de ejemplos
de proveedores externos. Las credenciales no se almacenan en Git: se inyectan
desde el Secret `litellm-models`.



## 🛠️ Tecnologías Utilizadas

* **Kubernetes (K3s):** Orquestación de contenedores.
* **ArgoCD:** CD declarativo para sincronización automática del estado deseado.
* **Kustomize:** Gestión de configuraciones por capas (Base y Overlays).
* **Traefik:** Ingress Controller para la gestión del tráfico externo y TLS.
* **Local Path Provisioner:** Persistencia de datos mediante volúmenes locales.

## 📁 Estructura del Repositorio

```text
.
├── argocd/             # Manifiestos de Application para ArgoCD (GitOps)
├── postgres/           # Base de datos (Deployment, Service, PVC)
├── litellm/            # Proxy de modelos con configuración Kustomize
└── openwebui/          # Interfaz web con Overlays para entorno Prod (Ingress/TLS)
```

## 🚀 Despliegue con GitOps

Este proyecto está diseñado para ser desplegado instantáneamente mediante ArgoCD.
1. Prerrequisitos

    Un clúster de Kubernetes funcionando (K3s recomendado).

    ArgoCD instalado en el namespace argocd.

2. Instalación

Para desplegar todo el stack, usa el instalador:

```bash
cp .env.example .env
chmod 700 scripts/install.sh
scripts/install.sh --env-file .env
```

El instalador valida que Ollama esté accesible en `http://127.0.0.1:11435` y
que los modelos `qwen3:14b` y `qwen3:30b` estén descargados antes de aplicar
los recursos. Si ya tienes ArgoCD, Traefik y cert-manager, responde `yes` a
la primera pregunta para conservarlos.

También se pueden aplicar manualmente los manifiestos de orquestación:

```bash
kubectl apply -f Proxygpt/argocd/
```

ArgoCD se encargará de sincronizar los recursos en el orden correcto, gestionando las dependencias y asegurando que el estado del clúster coincida con este repositorio.

Con el cluster de postgresql activado, el ultimo paso de despliegue será generar la base de datos para OpenWeb UI: 

```bash
kubectl exec -it $(kubectl get pod -l app=postgres -o name) -- psql -U admin -d litellm -c "CREATE DATABASE openwebui_db;"
```

### Modelos de LiteLLM

La Application de LiteLLM usa `litellm/overlays/prod`, que incluye el
Certificate y el Ingress para `litellm.kta41.local`. El fichero
`litellm/base/config.yaml` define los alias `ollama-local`, `gpt-4o-mini` y
`claude-3-5-sonnet`. Para habilitar proveedores externos, crea el Secret en el
namespace `default` sin incluirlo en el repositorio:

```bash
kubectl create secret generic litellm-models -n default \
  --from-literal=openai-api-key='sk-...' \
  --from-literal=anthropic-api-key='sk-ant-...'
```

LiteLLM usa la red del host (`hostNetwork`) y accede a Ollama mediante
`http://127.0.0.1:11435`. El puerto 11435 evita el `portproxy` de Windows que
ocupa el 11434. Los alias `qwen3-14b` y `qwen3-30b` usan el adaptador
`ollama_chat`, necesario para preservar las llamadas de herramientas cuando
Open WebUI transmite la respuesta. Ollama está configurado para mantener un
solo modelo generativo cargado a la vez mediante
`OLLAMA_MAX_LOADED_MODELS=1`; al cambiar de modelo, descarga el anterior antes
de cargar el nuevo. En Windows, configúralo y reinicia Ollama:

```powershell
setx OLLAMA_MAX_LOADED_MODELS 1
```

Después de reiniciar Ollama, selecciona `qwen3-14b` o `qwen3-30b` en Open
WebUI. Ambos aparecen en el catálogo, pero solo el modelo utilizado queda
cargado en memoria.

Para descargar los modelos manualmente:

```bash
curl -fsS http://127.0.0.1:11435/api/pull -d '{"model":"qwen3:14b"}'
curl -fsS http://127.0.0.1:11435/api/pull -d '{"model":"qwen3:30b"}'
```

## 💡 Lecciones Aprendidas (Troubleshooting)

Durante el desarrollo, se resolvieron retos técnicos críticos, destacando:

    Persistencia Inmutable: Resolución de conflictos en la inmutabilidad de los PersistentVolumeClaims (PVC) al separar la gestión del almacenamiento de la lógica de aplicación en ArgoCD.

    GitOps Workflow: Migración de configuraciones estáticas a un flujo dinámico con Kustomize, permitiendo la reutilización de código entre bases y parches de producción.

    Seguridad de Secretos: Implementación de inyección de secretos en memoria para evitar la exposición de credenciales en el historial de Git.

## Fix Red WSL2 (Timeout Descargas)
Si los pods no tienen salida a internet o fallan los DNS en WSL2:

1. Cambiar Flannel a Host Gateway:
`echo "flannel-backend: host-gw" | sudo tee -a /etc/rancher/k3s/config.yaml`

2. Usar DNS externos puros:
`echo "nameserver 8.8.8.8" | sudo tee /etc/rancher/k3s/resolv.conf`
`echo "resolv-conf: /etc/rancher/k3s/resolv.conf" | sudo tee -a /etc/rancher/k3s/config.yaml`

3. Purgar y reiniciar:
`sudo systemctl stop k3s`
`sudo ip link delete cni0`
`sudo ip link delete flannel.1`
`sudo systemctl start k3s`

## Configuración versionada de Open WebUI

La configuración funcional de Open WebUI se mantiene en el repositorio
separado [`kta41/openwebui-ai-config`](https://github.com/kta41/openwebui-ai-config).
Este repositorio de infraestructura mantiene Kubernetes, Argo CD, Kustomize,
Secrets y la configuración declarativa de LiteLLM; el repositorio externo
mantiene los modelos personalizados, system prompts y documentación de
Knowledge Bases.

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
Sync Hook Job usa openwebui-sync-auth
        |
        v
POST /api/v1/models/sync
        |
        v
Open WebUI actualiza sus modelos personalizados
```

El Job usa el Service interno:

```text
http://open-webui-service.default.svc.cluster.local:8080
```

Por ello, la sincronización GitOps no depende del certificado CA del Ingress.
El CA sólo es necesario para acceder desde la máquina local a
`https://ia.kta41.local`.

### Activar la Application de Argo CD

La Application está en
[`argocd/openwebui-config-app.yaml`](argocd/openwebui-config-app.yaml).
Antes de aplicarla, crea el Secret con la API key de Open WebUI usando el
`.env` local ignorado por Git:

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

unset OPENWEBUI_API_KEY
```

El repositorio privado también debe estar registrado en Argo CD con un
Fine-grained Personal Access Token limitado a
`kta41/openwebui-ai-config` y con `Contents: Read-only`:

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

Aplica y verifica:

```bash
kubectl apply -f Proxygpt/argocd/openwebui-config-app.yaml
kubectl get application openwebui-config -n argocd
kubectl get jobs,pods -n default -l app=openwebui-model-sync
```

El estado esperado es `Synced`, `Healthy` y `Succeeded`.

### Modificar modelos y prompts

Edita el repositorio externo:

```bash
cd /home/Kta41/openwebui-ai-config
nano models/qwen3-14b-assistant.json
```

Si creas un JSON nuevo, añádelo explícitamente a
`kustomization.yaml`. Valida y publica:

```bash
python3 -m json.tool models/qwen3-14b-assistant.json >/dev/null
kubectl kustomize . >/dev/null
git add models/ kustomization.yaml
git commit -m "Update Open WebUI model"
git push
```

Argo CD detectará el commit, generará un nuevo ConfigMap y ejecutará el Job
automáticamente. La reconciliación es exacta: los modelos ausentes del payload
se eliminan de Open WebUI.

### Certificado CA local

El CA raíz está en el Secret `kta-root-ca` del namespace `cert-manager`:

```bash
kubectl get secret kta-root-ca \
  -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' |
  base64 -d |
  sudo tee /usr/local/share/ca-certificates/kta-root-ca.crt >/dev/null

sudo update-ca-certificates
```

Después, `curl https://ia.kta41.local/health` debe funcionar sin `-k`.
El Job de Argo CD no necesita este CA porque usa el Service interno HTTP.

## Documentación relacionada

- [Guía completa de instalación](../docs/INSTALL.md)
- [Contrato de configuración GitOps](../docs/CONFIG-GITOPS.md)
- [Configuración GitOps de Open WebUI](../docs/OPENWEBUI-GITOPS.md)
- [Repositorio de configuración Open WebUI](https://github.com/kta41/openwebui-ai-config)
- [Documentación de Open WebUI](https://docs.openwebui.com/)
- [Documentación de LiteLLM](https://docs.litellm.ai/)

## Seguridad

Nunca publicar `.env`, API keys, tokens de GitHub, `LITELLM_MASTER_KEY`,
`LITELLM_SALT_KEY`, claves de proveedores, JWT, cookies, sesiones, `tls.key` o
dumps de PostgreSQL. Las Functions y Tools de Open WebUI ejecutan código en el
servidor y deben revisarse como código privilegiado.
