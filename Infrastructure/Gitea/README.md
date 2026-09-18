# Gitea Infrastructure

This manifest deploys **Gitea** using the official Helm chart, optimized for a
lightweight cluster environment.

### Technical Decisions

1. **Database:** **SQLite3** is used instead of a dedicated PostgreSQL deployment
to reduce RAM and CPU consumption.
2. **Security:** `INSTALL_LOCK` is enabled to prevent accidental post-deployment
reconfiguration.
3. **Networking:** Native integration with the **Traefik** Ingress Controller
using `web` entrypoints.
4. **Resilience:** `ha` (High Availability) services are disabled to fit the
capacity of a local single-node cluster and avoid pods remaining *Pending* for
lack of resources.
