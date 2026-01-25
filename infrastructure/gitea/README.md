# Gitea Infrastructure

Este manifiesto despliega **Gitea** utilizando el Chart oficial de Helm, optimizado para un entorno ligero dentro del clúster.

### Decisiones Técnicas:
1. **Base de Datos:** Se utiliza **SQLite3** en lugar de un despliegue de PostgreSQL dedicado para reducir el consumo de recursos (RAM/CPU).
2. **Seguridad:** `INSTALL_LOCK` activado para evitar re-configuraciones accidentales post-despliegue.
3. **Networking:** Integración nativa con el Ingress Controller de **Traefik** utilizando Entrypoints de tipo `web`.
4. **Resiliencia:** Se han desactivado los servicios `ha` (High Availability) para ajustarse a la capacidad de un nodo local, evitando pods en estado *Pending* por falta de recursos.
