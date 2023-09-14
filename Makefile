
.PHONY: keywords
keywords:  ## generate keywords from wabt's lexer
	@python3 $(CURDIR)/script/keywords.py
