{{/* Tenant name, sanitized */}}
{{- define "tenant.name" -}}
{{- .Values.tenant.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels for all tenant resources */}}
{{- define "tenant.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: idp-platform
platform.idp/tenant: {{ include "tenant.name" . }}
platform.idp/environment: {{ .Values.tenant.environment }}
{{- end -}}

{{/* Selector labels for a given app (param: dict with root + appName) */}}
{{- define "tenant.appSelector" -}}
platform.idp/tenant: {{ include "tenant.name" .root }}
app.kubernetes.io/name: {{ .appName }}
{{- end -}}

{{/* Placement (nodeSelector + tolerations) shared by all tenant pods */}}
{{- define "tenant.placement" -}}
{{- with .Values.placement.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.placement.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
