{{- define "todo-spa.name" -}}
todo-spa
{{- end -}}

{{- define "todo-spa.fullname" -}}
{{ include "todo-spa.name" . }}
{{- end -}}
