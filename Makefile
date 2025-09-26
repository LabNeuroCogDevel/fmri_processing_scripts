.PHONY: test
test: .test-results.txt
script_files := preprocessDistortion preprocessFunctional preprocessMprage $(wildcard preproc_functions/*) $(wildcard test/*bats)

.test-results.txt:  $(script_files)
	cd test/;\
	bats --tap *bats | tee ../$@

.docker: Dockerfile $(script_files)
	docker build -t lncd/fmri_processing_scripts
	date > .docker

.test-docker: .docker
	docker run -it --env TEST_SKIP_R=1 --env MRI_STDDIR=/opt/fmri_processing_scripts --entrypoint=bats lncd/fmri_processing_scripts  --verbose-run /opt/fmri_processing_scripts/test/
