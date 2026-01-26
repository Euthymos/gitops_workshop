workspace "F5 -> Dual OpenShift Clusters" {

  !identifiers flat

  model {
    user = person "User" "" "Person"

    clientDevice = softwareSystem "Client Device" {
      browser = container "Client" "Used by the client" "Web Browser" "Client"
    }

    edge = softwareSystem "Edge" {
      f5 = container "F5 Load Balancer" "External VIP/GSLB" "F5 BIG-IP" "LB"
    }

    k8s = softwareSystem "OpenShift Platform" {

      // Cluster A elements (unique model elements)
      ingressA = container "Ingress Controller (A)" "Routes inbound traffic" "OpenShift Router" "Ingress"
      svcA_A   = container "Service A (A)" "Kubernetes Service" "Kubernetes Service" "K8sService"
      svcB_A   = container "Service B (A)" "Kubernetes Service" "Kubernetes Service" "K8sService"
      podA_A   = container "Workload A (A)" "Application instance running in a pod" "Container" "Pod"
      podB_A   = container "Workload B (A)" "Application instance running in a pod" "Container" "Pod"

      // Cluster B elements (mirror, also unique model elements)
      ingressB = container "Ingress Controller (B)" "Routes inbound traffic" "OpenShift Router" "Ingress"
      svcA_B   = container "Service A (B)" "Kubernetes Service" "Kubernetes Service" "K8sService"
      svcB_B   = container "Service B (B)" "Kubernetes Service" "Kubernetes Service" "K8sService"
      podA_B   = container "Workload A (B)" "Application instance running in a pod" "Container" "Pod"
      podB_B   = container "Workload B (B)" "Application instance running in a pod" "Container" "Pod"
    }

    // Relationships
    user -> browser "Uses"
    browser -> f5 "Sends requests" "HTTPS"
    f5 -> ingressA "Forwards traffic (cluster A)" "HTTPS"
    f5 -> ingressB "Forwards traffic (cluster B)" "HTTPS"

    ingressA -> svcA_A "Routes (host/path)" "HTTP(S)"
    ingressA -> svcB_A "Routes (host/path)" "HTTP(S)"
    svcA_A -> podA_A "Load-balances to endpoints" "TCP"
    svcB_A -> podB_A "Load-balances to endpoints" "TCP"

    ingressB -> svcA_B "Routes (host/path)" "HTTP(S)"
    ingressB -> svcB_B "Routes (host/path)" "HTTP(S)"
    svcA_B -> podA_B "Load-balances to endpoints" "TCP"
    svcB_B -> podB_B "Load-balances to endpoints" "TCP"

    // Deployment model
    // Deployment model
    prod = deploymentEnvironment "Production" {
      deploymentNode "Client Device" "" "Laptop/Phone" 1 {
        containerInstance browser
      }

      edgeNode = deploymentNode "Edge / DMZ" {
        containerInstance f5
      }

      clusterA = deploymentNode "OpenShift Cluster A" {
        deploymentNode "Ingress" "" "Ingress layer" 1 {
          tags "Kubernetes - ing"
          containerInstance ingressA
        }

        group "Services" {
          deploymentNode "Service A" {
            tags "Kubernetes - svc"
            containerInstance svcA_A
          }
          deploymentNode "Service B" {
            tags "Kubernetes - svc"
            containerInstance svcB_A
          }
        }

        deploymentNode "Deployment A" 1 {
          tags "Kubernetes - deploy"
          deploymentNode "Pod A1" {
            tags "Kubernetes - pod"
            containerInstance podA_A
          deploymentNode "Pod A2" {
            tags "Kubernetes - pod"
            containerInstance podA_A
          }
          }
        }

        deploymentNode "Deployment B" 1 {
          tags "Kubernetes - deploy"
          deploymentNode "Pod B1" {
            tags "Kubernetes - pod"
            containerInstance podB_A
          }
          deploymentNode "Pod B2" {
            containerInstance podB_A
          }
        }
      }

      clusterB = deploymentNode "OpenShift Cluster B" {
        deploymentNode "Ingress" "" "Ingress layer" 1 {
          tags "Kubernetes - ing"
          containerInstance ingressB
        }

        group "Services" {
          deploymentNode "Service A" {
            tags "Kubernetes - svc"
            containerInstance svcA_B
          }
          deploymentNode "Service B" {
            tags "Kubernetes - svc"
            containerInstance svcB_B
          }
        }

        deploymentNode "Deployment A" "" "Kubernetes Deployment" 1 {
          tags "Kubernetes - deploy"
          deploymentNode "Pod A1" {
            tags "Kubernetes - pod"
            containerInstance podA_B
          deploymentNode "Pod A2" {
            tags "Kubernetes - pod"
            containerInstance podA_B
          }
          }
        }

        deploymentNode "Deployment B" 1 {
          tags "Kubernetes - deploy"
          deploymentNode "Pod B1" {
            containerInstance podB_B
          }
          deploymentNode "Pod B2" {
            containerInstance podB_B
          }
        }
      }
    }
  }

  views {
    theme https://static.structurizr.com/themes/kubernetes-v0.3/theme.json
    deployment * prod "openshift" {
      include *
      autoLayout lr
    }

    styles {
      element "Person" {
        shape Person
      }

    element "Client" {
        shape Person
      }

      element "LB" {
        shape RoundedBox
      }
      element "Ingress" {
        shape RoundedBox
      }
      element "K8sService" {
        shape RoundedBox
      }
      element "Pod" {
        shape RoundedBox
      }
    }
  }
}
