{{/* Host name of a vCluster-synced Service.
     vCluster mangles synced Services as <svc>-x-<vcluster-ns>-x-<vcluster-name>.
     Inside the vCluster the namespace = tenant name and the vCluster name =
     vcluster-<tenant>-<env>, so:
       <tenant>-<app>-x-<tenant>-x-vcluster-<tenant>-<env>
     Param: dict "root" . "app" "customer-api"|"customer-web" */}}
{{- define "route.syncedSvc" -}}
{{- $t := .root.Values.tenant.name -}}
{{- $e := .root.Values.tenant.environment -}}
{{- printf "%s-%s-x-%s-x-vcluster-%s-%s" $t .app $t $t $e -}}
{{- end -}}

{{- define "route.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: idp-platform
platform.idp/tenant: {{ .Values.tenant.name }}
platform.idp/environment: {{ .Values.tenant.environment }}
platform.idp/layer: route
{{- end -}}
