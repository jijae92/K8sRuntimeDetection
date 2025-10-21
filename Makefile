.PHONY: up down falco sidekick demo logs clean

up:
	./scripts/kind_up.sh
falco:
	./scripts/install_falco.sh
sidekick:
	./scripts/install_sidekick_stdout.sh
demo:
	./scripts/demo_triggers.sh
logs:
	kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=200
down:
	./scripts/cleanup.sh
clean: down