SHELL := /bin/bash
PORT ?= 1313

ifeq ($(origin VSCODE_PROXY_URI), environment)
BASEURL := $(shell echo $${VSCODE_PROXY_URI/\{\{port\}\}/$(PORT)})
else
BASEURL := http://localhost:$(PORT)/
endif

dev:
	hugo server -p $(PORT) --baseURL "$(BASEURL)" --appendPort=false --bind 0.0.0.0


# Pushes main from private to public.
push:
	@if [ "$$(git rev-parse --abbrev-ref HEAD)" != "main" ] || \
       [ "$$(git rev-parse --abbrev-ref --symbolic-full-name @{u})" != "private/main" ]; then \
      echo "Error: Must be on 'main' branch tracking 'private/main'."; exit 1; \
    fi
	git fetch private main
	git push public private/main:main

# Syncs main from public to private with rebase.
sync:
	@if [ "$$(git rev-parse --abbrev-ref HEAD)" != "main" ] || \
       [ "$$(git rev-parse --abbrev-ref --symbolic-full-name @{u})" != "private/main" ]; then \
      echo "Error: Must be on 'main' branch tracking 'private/main'."; exit 1; \
    fi
	git fetch public main
	git checkout private/main
	git rebase public/main
	git push --force private HEAD:main
	git checkout main