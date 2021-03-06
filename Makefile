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
	mkdir $(HOME)/.kube
	go get sigs.k8s.io/kind
	kind create cluster --config kind.yml
	kind export kubeconfig --kubeconfig $(HOME)/.kube/kind
	kubectl --kubeconfig $(HOME)/.kube/kind apply -f https://docs.projectcalico.org/manifests/calico.yaml
