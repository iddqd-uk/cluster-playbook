#!/usr/bin/make

SHELL = /bin/sh

.PHONY : help shell lint clean
.DEFAULT_GOAL : help

help: ## Show this help
	@printf "\033[33m%s:\033[0m\n" 'Available commands'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[32m%-11s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

shell: ## Start shell into container with ansible
	docker-compose run --rm ansible sh

lint: ## Lint playbook
	docker-compose run --rm ansible-lint ansible-lint site.yml

clean: ## Make clean
	docker-compose down -v
