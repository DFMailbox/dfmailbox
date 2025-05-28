# Would use Justfile but Makefile though arcane is ubiquitous
.PHONY: build compliance_test

DOCKER_COMPOSE_RUN = docker compose -f docker-compose.yml
DOCKER_COMPOSE_COMPLIANCE = docker compose -f compliance-docker-compose.yml

build: .env
	$(DOCKER_COMPOSE_RUN) up --build

compliance_test: .env
	$(DOCKER_COMPOSE_COMPLIANCE) up --build

.env:
	@echo -e "\e[31mCannot find .env file, running ./gen_env.sh\e[0m"
	@./gen_env.sh
