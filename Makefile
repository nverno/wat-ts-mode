SCRIPT_DIR = $(CURDIR)/script

PARSE_TEST ?= $(CURDIR)/test/parse
WABT_TEST  ?= test/parse

.PHONY: keywords
keywords:  ## generate keywords from wabt's lexer
	@python3 $(CURDIR)/script/keywords.py

get-test: $(PARSE_TEST)
$(PARSE_TEST):
	$(SCRIPT_DIR)/get-tests --test-dir $(PARSE_TEST)
