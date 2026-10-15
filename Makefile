# Report template Makefile
#
# Usage:
#   make                  — build the examples (examples/*.pdf)
#   make install          — install the template, filters and defaults for system-wide use
#   make docker           — build the Docker image
#   make clean            — remove generated files

PANDOC      = pandoc
PANDOC_DATA = $(HOME)/.local/share/pandoc
EXAMPLES    = $(patsubst examples/%.md,examples/%.pdf,$(wildcard examples/*.md))
FILTERS     = $(wildcard filters/*.lua)

# Local builds read the template and filters straight from this checkout.
PANDOC_FLAGS = --data-dir=. --defaults=report-defaults.yaml --resource-path=examples

all: $(EXAMPLES)

examples/%.pdf: examples/%.md report.typst report-defaults.yaml $(FILTERS)
	$(PANDOC) $(PANDOC_FLAGS) $< -o $@

# Symlink the template and filters into pandoc's data dir so edits here take effect immediately
# (re-run after editing report-defaults.yaml, which is copied rather than linked).
# Afterwards: pandoc input.md -d report -o output.pdf
install:
	mkdir -p $(PANDOC_DATA)/templates $(PANDOC_DATA)/filters $(PANDOC_DATA)/defaults
	ln -sf $(CURDIR)/report.typst $(PANDOC_DATA)/templates/report.typst
	# a generated copy, not a symlink: the font path must be absolute outside this checkout
	sed 's#--font-path=fonts#--font-path=$(CURDIR)/fonts#' report-defaults.yaml > $(PANDOC_DATA)/defaults/report.yaml
	for f in $(FILTERS) filters/report.lua; do ln -sf $(CURDIR)/$$f $(PANDOC_DATA)/filters/$$(basename $$f); done
	@echo "Installed. Use: pandoc input.md -d report -o output.pdf"

IMAGE = typst-report
docker:
	docker build -t $(IMAGE) .

clean:
	rm -f examples/*.pdf

.PHONY: all install docker clean
