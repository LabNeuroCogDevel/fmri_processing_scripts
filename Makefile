.PHONY: test
test:
	cd test/;\
	bats --tap *bats
