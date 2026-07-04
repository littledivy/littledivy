TYPST ?= $(shell command -v typst || echo /opt/homebrew/bin/typst)
SRC := $(wildcard *.typ)
DOT := $(wildcard static/img/*.dot)
HTML := $(SRC:.typ=.html)
SVG := $(DOT:.dot=.svg)

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9\/_\.-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: $(SVG) $(HTML) ## Build everything

static/img/%.svg: static/img/%.dot ## Build DOT svgs
	dot -Tsvg $< -o $@

%.html: %.typ $(SVG) ## Build typst docs
	@echo "Compiling $< → $@"
	$(TYPST) compile --features html $< $@

fmt: ## Format typst files
	typstyle -i $(SRC)

clean: ## Clean HTML output
	rm -f $(HTML)

.PHONY: help all clean fmt
