TYPST := typst
SRC := $(wildcard *.typ)
HTML := $(SRC:.typ=.html)

all: $(HTML)

%.html: %.typ
	@echo "Compiling $< → $@"
	$(TYPST) compile --features html $< $@

fmt:
	typstyle -i $(SRC)

clean:
	rm -f $(HTML)

.PHONY: all clean fmt

