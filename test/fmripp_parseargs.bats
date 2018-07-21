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
 [ $funcFile == "fake" ]

}

# check setting trunc
@test "trunc == 4" {
 parse_args -trunc 4 -no_warp
 [ $n_rm_firstvols -eq 4 ]
 return 0
}

# we set rmautocorr with rmautocorr switch
@test "with rmautocorr" {
 parse_args -4d fake.nii.gz -rmautocorr  -bandpass_filter 0.009 .08
 [ $rmautocorr -eq 1 ]
 [ $funcFile == "fake" ]

}

@test "rmautocor and nuisance" {
 parse_args -4d fake.nii.gz -rmautocorr  -bandpass_filter 0.009 .08 -nuisance_regression 6motion
 [ $rmautocorr -eq 1 ]
 [ $funcFile == "fake" ]
}

@test "fail with rmautocorr and no bandpass_filter" {
 run parse_args -4d fake.nii.gz -rmautocorr  
 [ $status -ne 0 ]
}

@test "default without rmautocorr" {
 parse_args -4d fake.nii.gz
 [ $rmautocorr -eq 0 ]
 [ $funcFile == "fake" ]

}







