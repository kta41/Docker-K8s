#  AI-Stack GitOps: LiteLLM + Open WebUI + Postgres

Este repositorio contiene la arquitectura completa para desplegar un stack de Inteligencia Artificial privado y escalable en **Kubernetes**. La gestión de la infraestructura se realiza mediante un modelo **GitOps** utilizando **ArgoCD** y **Kustomize**.

![Status](https://img.shields.io/badge/Status-Production--Ready-green)
![K8s](https://img.shields.io/badge/Kubernetes-K3s-blue)
![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange)

## 🏗️ Arquitectura del Sistema

![Estado de ArgoCD](./deploy/img/dashboard.png)

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
├── deploy/             # Despliegues Kubernetes y Applications de Argo CD
│   ├── argocd/
│   ├── postgres/
│   ├── litellm/
│   └── openwebui/
├── Infrastructure/      # Argo CD, cert-manager, Traefik y Gitea
├── docs/
└── scripts/
```

El repositorio se denomina **ProxyGPT**. La carpeta `deploy/` contiene los
manifiestos del producto y evita duplicar el nombre en una ruta como
`ProxyGPT/Proxygpt/`.

### Migración del remoto y del directorio local

Después de renombrar el repositorio en GitHub de `Docker-K8s` a `ProxyGPT`,
actualiza el remoto y, si lo deseas, el directorio local:

```bash
cd /home/Kta41/Docker-K8s
git remote set-url origin https://github.com/kta41/ProxyGPT.git
cd /home/Kta41
mv Docker-K8s ProxyGPT
cd ProxyGPT
git status --short --branch
```

Haz el cambio de nombre en GitHub antes de ejecutar `git push` con la nueva
URL. Las Applications de Argo CD de `deploy/argocd/` ya apuntan a
`https://github.com/kta41/ProxyGPT.git`.

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
kubectl apply -f deploy/argocd/
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

## PostgreSQL y persistencia

PostgreSQL es el backend compartido del stack. LiteLLM utiliza la base
`litellm` y Open WebUI utiliza `openwebui_db`. El instalador crea los Secrets
de PostgreSQL y la instalación inicial requiere crear la base de Open WebUI
si todavía no existe:

```bash
kubectl exec -it $(kubectl get pod -l app=postgres -o name) -- \
  psql -U admin -d litellm -c "CREATE DATABASE openwebui_db;"
```

Los PVCs de PostgreSQL y Open WebUI son persistentes y no deben eliminarse
como parte de una sincronización normal de Argo CD.

## Evolución del stack

La rama inicial `feat/postgres-auto-init` consolidó el despliegue de
PostgreSQL, LiteLLM y Open WebUI con Argo CD, cert-manager, Traefik, Kustomize
y un instalador parametrizable. También incorporó:

- Overlays de dominio y certificados para LiteLLM y Open WebUI.
- Inyección de secretos sin guardarlos en Git.
- Validación de Ollama y de los modelos Qwen3 antes del despliegue.
- Acceso de LiteLLM al Ollama del host mediante `hostNetwork`.
- Compatibilidad con llamadas de herramientas y streaming de Ollama.

Esta rama añade el segundo repositorio `openwebui-ai-config`, la Application
de Argo CD y el Sync Hook Job para sincronizar modelos personalizados y
system prompts mediante la API oficial de Open WebUI.

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
[`deploy/argocd/openwebui-config-app.yaml`](deploy/argocd/openwebui-config-app.yaml).
Antes de aplicarla, crea el Secret con la API key de Open WebUI usando el
`.env` local ignorado por Git:

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
kubectl apply -f deploy/argocd/openwebui-config-app.yaml
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

- [Guía completa de instalación](docs/INSTALL.md)
- [Contrato de configuración GitOps](docs/CONFIG-GITOPS.md)
- [Configuración GitOps de Open WebUI](docs/OPENWEBUI-GITOPS.md)
- [Repositorio de configuración Open WebUI](https://github.com/kta41/openwebui-ai-config)
- [Documentación de Open WebUI](https://docs.openwebui.com/)
- [Documentación de LiteLLM](https://docs.litellm.ai/)

## Troubleshooting y lecciones aprendidas

### Persistencia y PostgreSQL

- PostgreSQL mantiene la persistencia de LiteLLM y Open WebUI mediante PVCs.
- La base `openwebui_db` debe existir antes de que Open WebUI arranque con
  `DATABASE_URL` apuntando a PostgreSQL.
- Los PVCs son recursos persistentes: no deben recrearse ni modificarse de
  forma destructiva durante una sincronización de Argo CD.
- Los cambios de almacenamiento deben separarse de los cambios de aplicación.

### Argo CD, K3s y red

- Argo CD sincroniza manifiestos desde Git y Kustomize compone bases y overlays.
- `argocd-repo-server` usa `hostNetwork: true` y
  `ClusterFirstWithHostNet` para evitar problemas de MTU, checksum offloading
  y DNS en WSL2 al descargar repositorios grandes.
- Traefik y cert-manager se despliegan mediante Applications de Argo CD.
- La Application de Open WebUI debe apuntar a la ruta Git correcta dentro de
  este repositorio, nunca a una ruta local del nodo.

### WSL2: timeouts, DNS y Flannel

Si los pods no tienen salida a Internet o fallan los DNS en WSL2:

1. Cambiar Flannel a host gateway:

   ```bash
   echo "flannel-backend: host-gw" | sudo tee -a /etc/rancher/k3s/config.yaml
   ```

2. Usar una resolución DNS explícita:

   ```bash
   echo "nameserver 8.8.8.8" | sudo tee -a /etc/rancher/k3s/resolv.conf
   echo "resolv-conf: /etc/rancher/k3s/resolv.conf" | sudo tee -a /etc/rancher/k3s/config.yaml
   ```

3. Reiniciar únicamente después de comprobar las interfaces existentes:

   ```bash
   sudo systemctl stop k3s
   sudo ip link delete cni0
   sudo ip link delete flannel.1
   sudo systemctl start k3s
   ```

### Ollama y modelos Qwen3

- LiteLLM accede a Ollama mediante `hostNetwork` en
  `http://127.0.0.1:11435`.
- El puerto 11435 evita el conflicto del portproxy de Windows que ocupa el
  puerto 11434.
- `ollama_chat` conserva las llamadas de herramientas durante el streaming.
- Se anuncian capacidades de function calling, parallel function calling y
  tool choice para los alias Qwen3.
- Para limitar la memoria GPU/RAM a un modelo cargado: `OLLAMA_MAX_LOADED_MODELS=1`.
- El instalador valida que `qwen3:14b` y `qwen3:30b` estén disponibles antes de
  aplicar los recursos.

Descarga manual:

```bash
curl -fsS http://127.0.0.1:11435/api/pull -d '{"model":"qwen3:14b"}'
curl -fsS http://127.0.0.1:11435/api/pull -d '{"model":"qwen3:30b"}'
```

### TLS y CA interno

El CA raíz `kta-root-ca` está en `cert-manager`. Si el cliente local muestra
`unable to get local issuer certificate`, instala `tls.crt` en el trust store;
no extraigas ni distribuyas `tls.key`. El Job GitOps no necesita este CA porque
usa el Service interno HTTP de Open WebUI.

### Secretos y configuración

- `.env` se usa sólo localmente y está excluido por `.gitignore`.
- Las API keys se inyectan en Kubernetes Secrets y nunca en Git.
- `LITELLM_SALT_KEY` debe permanecer constante mientras existan credenciales
  cifradas en la base de datos.
- El instalador valida dominios, disponibilidad de Ollama, Kustomize y Secrets
  antes de aplicar las Applications.
- No se deben mezclar sin política explícita los modelos de LiteLLM definidos en
  `config.yaml` con modelos gestionados desde la base de datos/Admin UI.

### Open WebUI GitOps

- `/api/v1/models/sync` requiere el esquema completo de la versión instalada,
  incluyendo `user_id`, `is_active`, `created_at` y `updated_at`.
- El hook obtiene el usuario administrador mediante `/api/v1/auths/`.
- Un Job hook fallido puede bloquear una operación; elimina únicamente el Job
  `openwebui-model-sync` y refresca la Application.
- La reconciliación exacta elimina modelos ausentes del payload. Revisa siempre
  el diff antes de borrar JSON del repositorio externo.

### Seguridad

No publicar `.env`, API keys, tokens de GitHub, JWT, cookies, claves de
proveedores, `tls.key` ni dumps de PostgreSQL. Functions y Tools ejecutan código
servidor y deben revisarse como código privilegiado.
