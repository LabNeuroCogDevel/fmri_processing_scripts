#!/usr/bin/env bats

####################
# test arg parsing #
####################

testdir=batsparseargstest
# go into a special temp dir
setup() {
 source ../preproc_functions/helper_functions
 source ../preproc_functions/parse_args
 [ ! -d $testdir ] && mkdir $testdir
 cd $testdir
 touch fake.nii.gz
}

# exit and remove temp dir
teardown() {
 cd ..
 rm -r $testdir
 return 0
}

# check default is to not trunc
@test "no trunc" {
 parse_args -4d fake.nii.gz
 [ $n_rm_firstvols -eq 0 ]
}
# check default is to not trunc
@test "trunc == 4" {
 parse_args -trunc 4 -no_warp
 [ $n_rm_firstvols -eq 4 ]
}



