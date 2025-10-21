.PHONY: up down falco sidekick demo logs clean

up:
	./scripts/kind_up.sh
falco-install-kind:
	./scripts/install_falco.sh kind
falco-install-eks:
	./scripts/install_falco.sh eks
falco: falco-install-kind
sidekick:
	./scripts/install_sidekick_stdout.sh
demo:
	./scripts/demo_triggers.sh
logs:
	kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=200
down:
	./scripts/cleanup.sh
clean: down