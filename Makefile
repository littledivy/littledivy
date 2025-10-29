TYPST := typst
SRC := $(wildcard *.typ)
DOT := $(wildcard static/img/*.dot)
HTML := $(SRC:.typ=.html)
SVG := $(DOT:.dot=.svg)

all: $(SVG) $(HTML)

static/img/%.svg: static/img/%.dot
	dot -Tsvg $< -o $@

%.html: %.typ $(SVG)
	@echo "Compiling $< → $@"
	$(TYPST) compile --features html $< $@

fmt:
	typstyle -i $(SRC)

clean:
	rm -f $(HTML)

.PHONY: all clean fmt

