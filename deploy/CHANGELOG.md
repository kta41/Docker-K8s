[Added/Changed] - 2026-09-09
Argo CD / K3s Infrastructure on WSL2

    argocd-repo-server Network Bypass: The Argo CD repository server deployment
    was modified to use the host network (`hostNetwork: true`). This avoids
    silent packet drops (MTU/TCP checksum offloading) in WSL2 NAT when downloading
    large packages (`git-upload-pack`) from GitHub, resolving `context deadline
    exceeded` errors.

    Hybrid DNS Resolution: The `dnsPolicy: ClusterFirstWithHostNet` policy was
    injected into the `argocd-repo-server` pod. This compensates for the loss of
    Kubernetes DNS caused by the network bypass, allowing the component to
    resolve internal service names such as `argocd-redis` while retaining Internet
    access through the host.

    GitOps Path Correction: The Argo CD Application definition for deploying the
    ProxyGPT project was corrected. The `spec.source.path` block now points to
    the correct relative path inside the remote repository (`deploy/litellm/base`)
    instead of referencing the local filesystem, resolving the `app path does not
    exist` error.
