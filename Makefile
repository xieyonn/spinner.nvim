.PHONY: fmt test

.DEFAULT_GOAL = test

fmt:
	stylua .
test:
	@busted
