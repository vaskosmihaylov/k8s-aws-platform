.DEFAULT_GOAL := help

TF_BOOTSTRAP_DIR := terraform/bootstrap
TF_ENV_DIR := terraform/environments/dev
CLUSTER_NAME := k8s-platform-dev
AWS_REGION := eu-west-1
MCP_KUBECONFIG := $(HOME)/.kube/mcp-viewer.kubeconfig

.PHONY: help bootstrap init plan apply destroy validate kubeconfig \
        port-forward-grafana port-forward-argocd port-forward-api \
        load-test verify teardown

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

bootstrap: ## Create S3 + DynamoDB state backend (one-time)
	cd $(TF_BOOTSTRAP_DIR) && terraform init && terraform apply

init: ## Initialize Terraform for dev environment
	cd $(TF_ENV_DIR) && terraform init

plan: ## Plan Terraform changes for dev
	cd $(TF_ENV_DIR) && terraform plan -out=tfplan

apply: ## Apply Terraform plan for dev
	cd $(TF_ENV_DIR) && terraform apply tfplan

destroy: ## Destroy dev environment infrastructure
	@echo "WARNING: This will destroy all dev infrastructure."
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(TF_ENV_DIR) && terraform destroy

validate: ## Run all pre-commit hooks
	pre-commit run --all-files

kubeconfig: ## Write dev cluster kubeconfig to $(MCP_KUBECONFIG) for the read-only MCP
	aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(AWS_REGION) \
		--kubeconfig $(MCP_KUBECONFIG)
	@echo "Kubeconfig written to $(MCP_KUBECONFIG)"
	@echo "Use: export KUBECONFIG=$(MCP_KUBECONFIG)  (or point kubectl/MCP at this file)"

port-forward-grafana: ## Port-forward Grafana to localhost:3000
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

port-forward-argocd: ## Port-forward ArgoCD to localhost:8443
	kubectl port-forward -n argocd svc/argocd-server 8443:443

port-forward-api: ## Port-forward demo-api to localhost:8080
	kubectl port-forward -n dev svc/demo-api 8080:80

load-test: ## Run load test against demo-api
	./scripts/load-test.sh

verify: ## Verify platform health
	./scripts/verify-platform.sh

teardown: ## Full teardown: destroy all infrastructure
	@echo "!!! FULL TEARDOWN - This destroys EVERYTHING !!!"
	@read -p "Type 'DESTROY' to confirm: " confirm && [ "$$confirm" = "DESTROY" ] || exit 1
	cd $(TF_ENV_DIR) && terraform destroy -auto-approve
