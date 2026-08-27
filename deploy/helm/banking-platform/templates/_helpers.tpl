{{/*
Per-service credential Secret. Renders an ExternalSecret (synced from AWS
Secrets Manager via External Secrets Operator + IRSA) when
.Values.externalSecrets.enabled is true; otherwise falls back to a plain
Secret sourced from .Values.secrets (kind/local dev default, no ESO
dependency). Either way the rendered object has the same name/namespace/keys,
so Deployments' envFrom.secretRef never changes.
Call with (dict "root" $ "name" "<svc>-secret" "app" "<svc>").
*/}}
{{- define "banking-platform.dbJwtSecret" -}}
{{- if .root.Values.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ .name }}
  namespace: {{ .root.Values.namespace }}
  labels:
    app: {{ .app }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .root.Values.externalSecrets.clusterSecretStore }}
    kind: ClusterSecretStore
  target:
    name: {{ .name }}
    creationPolicy: Owner
  data:
    - secretKey: POSTGRES_USER
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: db_user
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: db_password
    - secretKey: JWT_SECRET
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: jwt_secret
    - secretKey: JWT_ISSUER
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: jwt_issuer
{{- else }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  namespace: {{ .root.Values.namespace }}
  labels:
    app: {{ .app }}
type: Opaque
stringData:
  POSTGRES_USER: {{ .root.Values.secrets.dbUser | quote }}
  POSTGRES_PASSWORD: {{ .root.Values.secrets.dbPassword | quote }}
  JWT_SECRET: {{ .root.Values.secrets.jwtSecret | quote }}
  JWT_ISSUER: {{ .root.Values.secrets.jwtIssuer | quote }}
{{- end }}
{{- end }}

{{/*
JWT-only credential Secret (api-gateway doesn't talk to Postgres directly).
Same ExternalSecret/plain-Secret fallback behavior as dbJwtSecret above.
Call with (dict "root" $ "name" "<svc>-secret" "app" "<svc>").
*/}}
{{- define "banking-platform.jwtOnlySecret" -}}
{{- if .root.Values.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ .name }}
  namespace: {{ .root.Values.namespace }}
  labels:
    app: {{ .app }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .root.Values.externalSecrets.clusterSecretStore }}
    kind: ClusterSecretStore
  target:
    name: {{ .name }}
    creationPolicy: Owner
  data:
    - secretKey: JWT_SECRET
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: jwt_secret
    - secretKey: JWT_ISSUER
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: jwt_issuer
{{- else }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  namespace: {{ .root.Values.namespace }}
  labels:
    app: {{ .app }}
type: Opaque
stringData:
  JWT_SECRET: {{ .root.Values.secrets.jwtSecret | quote }}
  JWT_ISSUER: {{ .root.Values.secrets.jwtIssuer | quote }}
{{- end }}
{{- end }}

{{/*
Postgres superuser bootstrap Secret (POSTGRES_USER/POSTGRES_PASSWORD only) —
consumed by the in-cluster Postgres StatefulSet itself, same
ExternalSecret/plain-Secret fallback as above.
Call with (dict "root" $ "name" "<name>" "app" "<app>").
*/}}
{{- define "banking-platform.dbOnlySecret" -}}
{{- if .root.Values.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ .name }}
  namespace: {{ .root.Values.namespace }}
  labels:
    app: {{ .app }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .root.Values.externalSecrets.clusterSecretStore }}
    kind: ClusterSecretStore
  target:
    name: {{ .name }}
    creationPolicy: Owner
  data:
    - secretKey: POSTGRES_USER
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: db_user
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: {{ .root.Values.externalSecrets.secretsManagerKey }}
        property: db_password
{{- else }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  namespace: {{ .root.Values.namespace }}
  labels:
    app: {{ .app }}
type: Opaque
stringData:
  POSTGRES_USER: {{ .root.Values.secrets.dbUser | quote }}
  POSTGRES_PASSWORD: {{ .root.Values.secrets.dbPassword | quote }}
{{- end }}
{{- end }}
