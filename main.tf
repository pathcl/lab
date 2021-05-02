provider "kubernetes" {
  config_path = "~/.kube/kind"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/kind"
  }
}

resource "helm_release" "prometheus_operator" {
  name       = "prometheus-operator"
  namespace  = "kube-system"
  repository = "https://charts.helm.sh/stable"
  chart      = "prometheus-operator"


  values = [<<EOF
prometheus:
  prometheusSpec:
    additionalScrapeConfigsExternal: true
  additionalServiceMonitors:
  - name: juice-shop
    jobLabel: juice-shop
    selector:
      matchLabels:
        app.kubernetes.io/name: juice-shop
    namespaceSelector:
      matchNames:
      - development
    endpoints:
    - port: http
      interval: 30s
  - name: nginx-ingress-service-monitor
    jobLabel: nginx-ingress
    selector:
      matchLabels:
        app.kubernetes.io/name: ingress-nginx
    namespaceSelector:
      matchNames:
      - ingress-nginx
    endpoints:
    - port: metrics
      interval: 30s
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'nginx-ingress'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: true
        editable: true
        options:
          path: /var/lib/grafana/dashboards/nginx-ingress
  dashboards:
    nginx-ingress:
      nginx-ingress-controller:
        datasource: Prometheus
        gnetId: 9614
        revision: 1
EOF
  ]

  set {
    name  = "grafana.image.tag"
    value = "7.5.5"
  }

  set {
    name  = "grafana.adminPassword"
    value = "nologin"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.externalUrl"
    value = "https://alert.sanmartin.dev"
  }

  set {
    name  = "prometheus.prometheusSpec.externalUrl"
    value = "https://prom.sanmartin.dev"
  }

}


resource "helm_release" "keda" {
  name       = "keda"
  namespace  = "kube-system"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"

  set {
    name  = "image.keda.tag"
    value = "2.2.0"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  values = [
    file("nginx.yml")
  ]

}

resource "helm_release" "juice_shop" {
  name       = "juice-shop"
  namespace  = "development"
  repository = "https://charts.securecodebox.io"
  chart      = "juice-shop"

}

variable "namespaces" {
  type        = list(string)
  description = "the stuff you need"
  default     = ["ingress-nginx", "development"]

}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset(var.namespaces)
  metadata {
    name = each.value
  }
}


resource "kubernetes_ingress" "juice_shop" {

  metadata {
    name      = "juice-shop-frontend"
    namespace = "development"

    annotations = {
      "nginx.ingress.kubernetes.io/modsecurity-snippet" = "SecRuleEngine On \n"
    }
  }

  spec {

    rule {
      host = "demo.sanmartin.dev"
      http {
        path {
          backend {
            service_name = "juice-shop"
            service_port = 3000
          }

          path = "/"
        }

      }
    }

    tls {
      hosts       = ["demo.sanmartin.dev"]
      secret_name = "wildcard"
    }
  }
}



resource "kubernetes_ingress" "grafana" {

  metadata {
    name      = "grafana"
    namespace = "kube-system"
  }

  spec {

    rule {
      host = "grafana.sanmartin.dev"
      http {
        path {
          backend {
            service_name = "prometheus-operator-grafana"
            service_port = 80
          }

          path = "/"
        }

      }
    }

    tls {
      hosts       = ["grafana.sanmartin.dev"]
      secret_name = "wildcard"
    }
  }
}

resource "kubernetes_ingress" "prometheus" {

  metadata {
    name      = "prometheus"
    namespace = "kube-system"
  }

  spec {

    rule {
      host = "prom.sanmartin.dev"
      http {
        path {
          backend {
            service_name = "prometheus-operator-prometheus"
            service_port = 9090
          }

          path = "/"
        }

      }
    }

    tls {
      hosts       = ["prom.sanmartin.dev"]
      secret_name = "wildcard"
    }
  }
}


resource "kubernetes_secret" "juice_shop" {
  depends_on = [helm_release.juice_shop]
  metadata {
    name      = "wildcard"
    namespace = "development"
  }

  data = {
    "tls.key" = acme_certificate.certificate.private_key_pem
    "tls.crt" = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
  }

  type = "kubernetes.io/tls"
}


resource "kubernetes_secret" "prometheus_operator" {
  depends_on = [helm_release.juice_shop]
  metadata {
    name      = "wildcard"
    namespace = "kube-system"
  }

  data = {
    "tls.key" = acme_certificate.certificate.private_key_pem
    "tls.crt" = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
  }

  type = "kubernetes.io/tls"
}


provider "kubernetes-alpha" {
  config_path = "~/.kube/kind"
}


resource "kubernetes_manifest" "keda_scaled_object" {
  provider = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: juice-shop-scaledobject
  namespace: development
spec:
  pollingInterval: 5
  cooldownPeriod: 30
  minReplicaCount: 3
  maxReplicaCount: 10
  scaleTargetRef:
    name: juice-shop
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-operator-prometheus:9090/
      metricName: http_requests_count
      threshold: '3'
      query: sum(rate(http_requests_count{status_code="2XX",app="juiceshop"}[1m]))
EOT
  )
}

resource "kubernetes_manifest" "juice_shop_network_policy_egress" {
  depends_on = [helm_release.juice_shop]
  provider   = kubernetes-alpha
  manifest = yamldecode(<<EOT
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: development
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOT
  )
}


resource "kubernetes_limit_range" "juice_shop" {
  depends_on = [helm_release.juice_shop]
  metadata {
    name      = "juice-shop"
    namespace = "development"
  }
  spec {
    limit {
      type = "Pod"
      max = {
        cpu    = "200m"
        memory = "1024Mi"
      }
    }
    limit {
      type = "Container"
      default = {
        cpu    = "50m"
        memory = "24Mi"
      }
    }
  }
}


resource "kubernetes_pod_disruption_budget" "juice_shop" {
  metadata {
    name      = "juice-shop"
    namespace = "development"
  }
  spec {
    max_unavailable = "20%"
    selector {
      match_labels = {
        name = "juice-shop"
      }
    }
  }
}
