#!/bin/bash
SCRIPT_DIR=$(dirname "$0")

REPOSITORY="https://helm.traefik.io/traefik"
VERSION="38.0.1"

NAMESPACE="traefik"

TLS_STORE_NAME="traefik-tls-certificate"

# Create Namespace
if ! kubectl get namespace ${NAMESPACE} ; then
  kubectl create namespace ${NAMESPACE}
fi

if ! kubectl get secret -n ${NAMESPACE} ${TLS_STORE_NAME} ; then
  kubectl create secret tls ${TLS_STORE_NAME} \
          -n ${NAMESPACE} \
          --cert="${SCRIPT_DIR}"/cert/gitops.jwausle.de.pem \
          --key="${SCRIPT_DIR}"/cert/gitops.jwausle.de.key
fi


# Create docker secret as imagePullSecrets
TMP_FILE=$(mktemp -t traefik-values-XXX)
cat <<EOF > "${TMP_FILE}"
additionalArguments:
  - "--accesslog=true"
  - "--log.level=DEBUG"
  - "--serversTransport.insecureSkipVerify=true"

deployment:
  replicas: 1

ingressRoute:
  dashboard:
    enabled: true
EOF

helm repo add traefik ${REPOSITORY}
helm upgrade --install traefik traefik/traefik \
     -n $NAMESPACE \
     --version ${VERSION} \
     --values "${TMP_FILE}"

TMP_FILE=$(mktemp -t workload-XXX)
cat <<EOF > "${TMP_FILE}"
apiVersion: traefik.io/v1alpha1
kind: TLSStore
metadata:
  name: default

spec:
  defaultCertificate:
    secretName: $TLS_STORE_NAME
EOF

kubectl apply -f "$TMP_FILE"