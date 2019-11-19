.PHONY: test
test: .test-results.txt

.test-results.txt:  preprocessDistortion preprocessFunctional preprocessMprage $(wildcard preproc_functions/*) $(wildcard test/*bats)
	cd test/;\
	bats --tap *bats | tee ../$@
