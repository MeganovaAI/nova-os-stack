{{/* Base name = tenant slug (release name is expected to match, but tenant wins). */}}
{{- define "nova-os.name" -}}
{{- default .Release.Name .Values.tenant | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nova-os.fullname" -}}
{{- printf "nova-os-%s" (include "nova-os.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "nova-os.labels" -}}
app.kubernetes.io/name: nova-os
app.kubernetes.io/instance: {{ include "nova-os.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
nova-os.meganova.ai/tenant: {{ include "nova-os.name" . }}
{{- end -}}

{{- define "nova-os.selectorLabels" -}}
app.kubernetes.io/name: nova-os
app.kubernetes.io/instance: {{ include "nova-os.name" . }}
{{- end -}}

{{/* Fully-qualified image reference. */}}
{{- define "nova-os.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/* The tenant's public host: explicit override, else <tenant>.<domain>. */}}
{{- define "nova-os.host" -}}
{{- if .Values.ingress.host -}}
{{- .Values.ingress.host -}}
{{- else -}}
{{- printf "%s.%s" (include "nova-os.name" .) .Values.ingress.domain -}}
{{- end -}}
{{- end -}}

{{- define "nova-os.publicUrl" -}}
{{- .Values.publicUrl | default (printf "https://%s" (include "nova-os.host" .)) -}}
{{- end -}}

{{/* Per-tenant Postgres database name and SurrealDB namespace. */}}
{{- define "nova-os.dbName" -}}
{{- .Values.database.name | default (include "nova-os.name" .) -}}
{{- end -}}

{{- define "nova-os.surrealNs" -}}
{{- .Values.surreal.namespace | default (include "nova-os.name" .) -}}
{{- end -}}

{{/* Name of the Secret holding tenant credentials. */}}
{{- define "nova-os.secretName" -}}
{{- .Values.secrets.existingSecret | default (printf "%s-secrets" (include "nova-os.fullname" .)) -}}
{{- end -}}

{{/* NOVA_OS_DATABASE_URL: explicit full URL wins; else compose from parts,
     targeting the bundled Postgres service when postgres.enabled. */}}
{{- define "nova-os.databaseUrl" -}}
{{- if .Values.secrets.databaseUrl -}}
{{- .Values.secrets.databaseUrl -}}
{{- else if .Values.postgres.enabled -}}
{{- printf "postgresql://%s:%s@%s-postgres:5432/%s" .Values.database.user .Values.secrets.postgresPassword (include "nova-os.fullname" .) (include "nova-os.dbName" .) -}}
{{- else -}}
{{- printf "postgresql://%s:%s@%s:%v/%s" .Values.database.user .Values.secrets.postgresPassword .Values.database.host .Values.database.port (include "nova-os.dbName" .) -}}
{{- end -}}
{{- end -}}

{{/* In-cluster SurrealDB URL when bundled, else the external one. */}}
{{- define "nova-os.surrealUrl" -}}
{{- if .Values.surrealdb.enabled -}}
{{- printf "ws://%s-surrealdb:8000/rpc" (include "nova-os.fullname" .) -}}
{{- else -}}
{{- .Values.surreal.url -}}
{{- end -}}
{{- end -}}
