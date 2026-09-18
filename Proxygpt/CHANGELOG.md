[Added/Changed] - 2026-09-09
Infraestructura / ArgoCD & K3s en WSL2

    argocd-repo-server Network Bypass: Se ha modificado el despliegue del servidor de repositorios de ArgoCD para utilizar la red del anfitrión (hostNetwork: true). Esto evita los descartes silenciosos de paquetes (MTU/TCP Checksum Offloading) en el NAT de WSL2 al descargar paquetes grandes (git-upload-pack) desde GitHub, resolviendo los errores de context deadline exceeded.

    Resolución DNS Híbrida: Se ha inyectado la política dnsPolicy: ClusterFirstWithHostNet en el pod argocd-repo-server. Esto compensa la pérdida del DNS de Kubernetes provocada por el bypass de red anterior, permitiendo que el componente vuelva a resolver nombres de servicios internos (como argocd-redis) sin perder su salida a internet a través del host.

    Corrección de Rutas GitOps: Se ha corregido la definición de la Application de ArgoCD para el despliegue del proyecto ProxyGPT. El bloque spec.source.path ahora apunta a la ruta relativa correcta dentro del repositorio remoto (Proxygpt/litellm/base) en lugar de referenciar el sistema de archivos local, resolviendo el error app path does not exist. 
