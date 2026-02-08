.DEFAULT_GOAL = test

LUA_FILES := $(shell find . -name "*.lua" ! -path "./.git/*")
MD_FILES := README.md CONTRIBUTING.md
SH_FILES := test/bin/lua.sh scripts/**
YAML_FILES := .github/workflows/test.yaml .github/workflows/stylua.yaml

.PHONY: fmt test cov doc

fmt:
	@stylua $(LUA_FILES)
	@prettier --write $(MD_FILES)
	@prettier --write $(YAML_FILES)
	@shfmt -w --indent 4 -bn -ci -sr $(SH_FILES)
test:
	@busted
cov:
	@rm -f luacov.stats.out luacov.report.out
	@LUACOV=1 busted
	@luacov
	@sed -n '/Summary/,$$p' luacov.report.out
doc:
	@scripts/doc.sh
	doctoc README.md
	@$(MAKE) fmt
