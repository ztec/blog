SHELL := /bin/bash
PORT ?= 1313

ifeq ($(origin VSCODE_PROXY_URI), environment)
BASEURL := $(shell echo $${VSCODE_PROXY_URI/\{\{port\}\}/$(PORT)})
else
BASEURL := http://localhost:$(PORT)/
endif

run:
	hugo server -p $(PORT) --baseURL "$(BASEURL)" --appendPort=false


# Pushes main from private to public.
push-public:
	git fetch private main
	git push public private/main:main

# Syncs main from public to private with rebase.
sync-public:
	git fetch public main
	git checkout private/main
	git rebase public/main
	git push --force private HEAD:main
	git checkout main