{{/*
Expand the name of the chart.
*/}}
{{- define "crusoe-registry-token-rotator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "crusoe-registry-token-rotator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "crusoe-registry-token-rotator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "crusoe-registry-token-rotator.labels" -}}
helm.sh/chart: {{ include "crusoe-registry-token-rotator.chart" . }}
{{ include "crusoe-registry-token-rotator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "crusoe-registry-token-rotator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crusoe-registry-token-rotator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "crusoe-registry-token-rotator.serviceAccountName" -}}
{{- if .Values.rbac.create }}
{{- .Values.rbac.serviceAccount.name | default (include "crusoe-registry-token-rotator.fullname" .) }}
{{- else }}
{{- .Values.rbac.serviceAccount.name | default "default" }}
{{- end }}
{{- end }}