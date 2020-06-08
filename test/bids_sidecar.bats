#!/usr/bin/env bats

####################
# test arg parsing #
####################
export testdir=batsparseargstest
export funcdir=./
# go into a special temp dir
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/parse_args
 source ../preproc_functions/helper_functions
 [ ! -d $testdir ] && mkdir $testdir
 cd $testdir
 touch fake.nii.gz
 echo '{"RepetitionTime": 2, "SliceTiming": [0.5, 1, 1.5] }' > fake.json
 echo '{"RepetitionTime": 3, "SliceTiming": [0.5, 1, 1.5] }' > other_fake.json
}

# exit and remove temp dir
teardown() {
 cd ..
 rm -r $testdir
 return 0
}


@test "load_func_bids" {
 load_func_bids fake.json
 [ "$tr" -eq 2 ]
 [ "$(cat .bids_custom_slice.txt)" == "0.5,1,1.5" ]
 load_func_bids other_fake.json
 [ "$tr" -eq 3 ]
}
