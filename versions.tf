terraform {
  backend "s3" {
    bucket = "tfdev"
    key    = "klab"
    region = "us-east-1"
  }
  required_providers {
    acme = {
      source = "vancluever/acme"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    local = {
      source = "hashicorp/local"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
  required_version = ">= 0.14.8"
}
