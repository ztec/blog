SHELL := /bin/bash
PORT ?= 1313

ifeq ($(origin VSCODE_PROXY_URI), environment)
BASEURL := $(shell echo $${VSCODE_PROXY_URI/\{\{port\}\}/$(PORT)})
else
BASEURL := http://localhost:$(PORT)/
endif

dev:
	hugo server -p $(PORT) --baseURL "$(BASEURL)" --appendPort=false --bind 0.0.0.0

update-theme:
	git submodule update --remote --rebase

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

# Convert SVG type icons to PNG with theme colors
# Theme white: #e7dfd2, Theme dark: #0f1115
convert-type-icons:
	@echo "Converting SVG type icons to PNG..."
	@for dir in themes/VHS/assets/icons/types assets/icons/types; do \
		if [ -d "$$dir" ]; then \
			echo "Processing directory: $$dir"; \
			for svg in $$dir/*.svg; do \
				if [ -f "$$svg" ]; then \
					basename=$$(basename "$$svg" .svg); \
					png="$$dir/$$basename.png"; \
					echo "  Converting $$basename.svg to $$basename.png"; \
					magick -size 160x160 "$$svg" -background none -channel RGB -negate +channel \
						-fuzz 10% -transparent black -background "#0f1115" -flatten "$$png"; \
				fi; \
			done; \
		fi; \
	done
	@echo "Creating rounded corner background for type icon (80px icon + 20px padding = 120px)..."
	@magick -size 120x120 xc:none -fill "#0f1115" \
		-draw "rectangle 0,0 112,119" \
		-draw "rectangle 0,0 119,112" \
		-draw "roundrectangle 104,104 119,119 8,8" \
		themes/VHS/assets/icon-bg-rounded.png
	@echo "Done!"