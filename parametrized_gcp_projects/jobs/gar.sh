gcloud auth activate-service-account ${MY SERVICE ACCOUNT EMAIL} --key-file=${GOOGLE_APPLICATION_CREDENTIALS} --project=${MY PROJECT ID}
gcloud auth configure-docker ${REGION}-docker.pkg.dev
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add external-secrets https://charts.external-secrets.io
# for cert manager
helm repo add jetstack https://charts.jetstack.io
# for reloader
helm repo add stakater-charts https://stakater.github.io/stakater-charts
helm repo update
# Copy ingress-nginx resources to GAR
helm pull ingress-nginx/ingress-nginx --version ${INGRESS_V}
helm push ingress-nginx-${INGRESS_V}.tgz ${GAR_OCI}
gcrane cp ${INGRESS_DOCKER_URL}/${INGRESS_KUBE_WEBHOOK} ${GAR_URL}/${INGRESS_KUBE_WEBHOOK}
gcrane cp ${INGRESS_DOCKER_URL}/${INGRESS_CONTROLLER} ${GAR_URL}/${INGRESS_CONTROLLER}
gcrane cp ${INGRESS_DOCKER_URL}/${DEFAULT_BACKEND} ${GAR_URL}/${DEFAULT_BACKEND}
# Copy certificate manager resources to GAR
helm pull jetstack/cert-manager --version ${CERTMAN_V}
helm push cert-manager-${CERTMAN_V}.tgz ${GAR_OCI}
gcrane cp quay.io/jetstack/cert-manager-controller:${CERTMAN_V} ${GAR_URL}/cert-manager-controller:${CERTMAN_V}
gcrane cp quay.io/jetstack/cert-manager-webhook:${CERTMAN_V} ${GAR_URL}/cert-manager-webhook:${CERTMAN_V}
gcrane cp quay.io/jetstack/cert-manager-cainjector:${CERTMAN_V} ${GAR_URL}/cert-manager-cainjector:${CERTMAN_V}
gcrane cp quay.io/jetstack/cert-manager-acmesolver:${CERTMAN_V} ${GAR_URL}/cert-manager-acmesolver:${CERTMAN_V}
gcrane cp quay.io/jetstack/cert-manager-ctl:${CERTMAN_V} ${GAR_URL}/cert-manager-ctl:${CERTMAN_V}
# Copy external-secrets resources to GAR
helm pull external-secrets/external-secrets --version ${EXTERNAL_SECRETS_V}
helm push external-secrets-${EXTERNAL_SECRETS_V}.tgz ${GAR_OCI}
gcrane cp ghcr.io/external-secrets/external-secrets:v${EXTERNAL_SECRETS_V} ${GAR_URL}/external-secrets:v${EXTERNAL_SECRETS_V}
# Copy reloader resources to GAR
helm pull stakater-charts/reloader --version ${RELOADER_V}
helm push reloader-${RELOADER_V}.tgz ${GAR_OCI}
gcrane cp ghcr.io/stakater/reloader:v${RELOADER_V} ${GAR_URL}/reloader:v${RELOADER_V}
