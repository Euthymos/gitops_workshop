{{- define "todos-spa.name" -}}
todo-spa
{{- end -}}

{{- define "todos-spa.fullname" -}}
{{ include "todos-spa.name" . }}
{{- end -}}
