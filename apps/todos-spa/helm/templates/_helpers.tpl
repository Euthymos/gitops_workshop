{{- define "todos-spa.name" -}}
todos-spa
{{- end -}}

{{- define "todos-spa.fullname" -}}
{{ include "todos-spa.name" . }}
{{- end -}}
