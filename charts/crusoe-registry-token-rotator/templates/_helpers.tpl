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
Namespace the chart installs into. Always the release namespace. The deprecated
.Values.namespace is honoured only when it agrees; when it disagrees we fail rather
than relocate every object, which is what Helm would otherwise do on upgrade.
*/}}
{{- define "crusoe-registry-token-rotator.namespace" -}}
{{- if and .Values.namespace (ne .Values.namespace .Release.Namespace) -}}
{{- fail (printf "`namespace` is set to %q but the release namespace is %q. This key is deprecated and resources now install into the release namespace. Either drop it from your values and reinstall with `--namespace %s`, or set it to %q to confirm. Upgrading in place cannot move resources between namespaces." .Values.namespace .Release.Namespace .Values.namespace .Release.Namespace) -}}
{{- end -}}
{{- .Release.Namespace -}}
{{- end }}

{{/*
Whether the chart creates the ServiceAccount, ClusterRole and RoleBindings.
serviceAccount.create is canonical; the deprecated rbac.create overrides it when
explicitly set. Returns "true" or the empty string, so callers can use `if include`.
*/}}
{{- define "crusoe-registry-token-rotator.createRBAC" -}}
{{- $create := .Values.serviceAccount.create -}}
{{- $rbac := .Values.rbac | default dict -}}
{{- if not (kindIs "invalid" $rbac.create) -}}
{{- $create = $rbac.create -}}
{{- end -}}
{{- if $create -}}true{{- end -}}
{{- end }}

{{/*
Create the name of the service account to use. serviceAccount.name is canonical;
the deprecated rbac.serviceAccount.name overrides it when set.
*/}}
{{- define "crusoe-registry-token-rotator.serviceAccountName" -}}
{{- $name := .Values.serviceAccount.name -}}
{{- $rbac := .Values.rbac | default dict -}}
{{- $legacy := ($rbac.serviceAccount | default dict).name -}}
{{- if $legacy -}}
{{- $name = $legacy -}}
{{- end -}}
{{- if and (not (include "crusoe-registry-token-rotator.createRBAC" .)) (not $name) -}}
{{- fail "serviceAccount.create is false, so the chart creates no ServiceAccount. Set serviceAccount.name to an existing account, or set serviceAccount.create to true." -}}
{{- end -}}
{{- default (include "crusoe-registry-token-rotator.fullname" .) $name -}}
{{- end }}