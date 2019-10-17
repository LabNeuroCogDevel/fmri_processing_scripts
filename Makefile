.PHONY: test
test: .test-results.txt

.test-results.txt:  preprocessDistortion preprocessFunctional preprocessMprage $(wildcard preproc_functions/*)
	cd test/;\
	bats --tap *bats | tee ../$@
