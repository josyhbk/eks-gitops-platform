CLUSTER  ?= local
KIND_NAME ?= gitops-lab
REPO_URL ?= https://github.com/josyhbk/eks-gitops-platform.git
REVISION ?= main
# Same chart version Argo CD manages later, read from clusters/values.yaml
ARGOCD_VERSION := $(shell grep -A6 '^  argocd:' clusters/values.yaml | awk '/version:/{print $$2}')

.PHONY: up cluster argocd root wait password down

up: cluster argocd root wait

cluster:
	kind get clusters | grep -qx $(KIND_NAME) || kind create cluster --name $(KIND_NAME) --config bootstrap/kind.yaml

argocd:
	helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm \
	  --version $(ARGOCD_VERSION) --namespace argocd --create-namespace \
	  --values platform/argocd/values.yaml --wait

root:
	sed -e 's|REPO_URL|$(REPO_URL)|g' -e 's|REVISION|$(REVISION)|g' -e 's|CLUSTER|$(CLUSTER)|g' \
	  bootstrap/root.yaml | kubectl apply -f -

wait:
	bootstrap/wait.sh

password:
	@echo "argocd  admin / $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@echo "grafana admin / $$(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"

down:
	kind delete cluster --name $(KIND_NAME)
