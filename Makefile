# Would use Justfile but Makefile though arcane is ubiquitous
.PHONY: up compliance_test

DOCKER_COMPOSE_RUN = docker compose -f docker-compose.yml
DOCKER_COMPOSE_COMPLIANCE = docker compose -f compliance-docker-compose.yml

up: .env
	$(DOCKER_COMPOSE_RUN) up --build

watch: .env
	$(DOCKER_COMPOSE_RUN) watch

compliance_test: .env
	cd compliance; \
	go test -count=1 ./...

compliance_test_verbose: .env
	cd compliance; \
	go test -count=1 -v ./...

up_compliance:
	$(DOCKER_COMPOSE_COMPLIANCE) up --build


.env:
	@echo -e "\e[31mCannot find .env file, running ./gen_env.sh\e[0m"
	@./gen_env.sh
