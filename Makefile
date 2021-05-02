SHELL := /usr/bin/env bash
CWD := $(shell pwd)

clean:
	terraform destroy -auto-approve

build:
	terraform apply -target helm_release.keda -auto-approve
	terraform apply -auto-approve

plan:
	terraform plan

init:
	kind create cluster --config kind.yml
	kind export kubeconfig --kubeconfig /home/pathcl/.kube/kind
	kubectl --kubeconfig /home/pathcl/.kube/kind apply -f https://docs.projectcalico.org/manifests/calico.yaml
