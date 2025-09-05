SHELL := /bin/bash
PORT ?= 1313

ifeq ($(origin VSCODE_PROXY_URI), environment)
BASEURL := $(shell echo $${VSCODE_PROXY_URI/\{\{port\}\}/$(PORT)})
else
BASEURL := http://localhost:$(PORT)/
endif

run:
	hugo server -p $(PORT) --baseURL "$(BASEURL)" --appendPort=false