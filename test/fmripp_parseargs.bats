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
}

# exit and remove temp dir
teardown() {
 cd ..
 rm -r $testdir
 return 0
}


@test "cite" {
 run parse_args -cite
 [ $status -eq 0 ]
 [ ${#lines} -gt 10 ]
}

# physio usage
@test "physio input: expected" {
 ! command -v siemphysdat && skip
 touch junk.txt junk.puls junk.json
 mkdir mrdir
 run parse_args -4d fake.nii.gz -physio_card junk.puls -physio_resp junk.txt -physio_func_info junk.json 
 [ $status -eq 0 ]
 run parse_args -4d fake.nii.gz -physio_card junk.puls -physio_resp junk.txt -physio_func_info mrdir 
 [ $status -eq 0 ]
}
@test "physio input: fails" {
 ! command -v siemphysdat && skip
 touch junk.txt junk.puls junk.json
 # need both card and resp
 run parse_args -4d fake.nii.gz -physio_card junk.txt 
 [ $status -ne 0 ]
 run parse_args -4d fake.nii.gz -physio_resp junk.txt 
 [ $status -ne 0 ]
 # need phsio_func_info
 run parse_args -4d fake.nii.gz -physio_card junk.puls -physio_resp junk.txt
 [ $status -ne 0 ]
}

# check default is to not trunc
@test "no trunc" {
 pwd
 parse_args -4d fake.nii.gz
 [ $n_rm_firstvols -eq 0 ]
 [ $funcFile == "fake" ]

}

@test "no mc" {
 pwd
 parse_args -4d fake.nii.gz
 [ $no_mc -eq 0 ]
 parse_args -4d fake.nii.gz -no_mc
 [ $no_mc -eq 1 ]
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

# this restraint has been removed! (when, why?, noted after the fact on 20181029) 
# @test "fail with rmautocorr and no bandpass_filter" {
#  run parse_args -4d fake.nii.gz -rmautocorr  
#  [ $status -ne 0 ]
# }

@test "default without rmautocorr" {
 parse_args -4d fake.nii.gz
 [ $rmautocorr -eq 0 ]
 [ $funcFile == "fake" ]

}


@test "fail if gsr but not in regression" {
 run parse_args -4d fake.nii.gz -gsr 
 [ $status -ne 0 ]

 run parse_args -4d fake.nii.gz -gsr -nuisance_regression wm,dwm
 [ $status -ne 0 ]
}
@test "gsr and nuisance_regression" {
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression gs
 [ $status -eq 0 ]
 parse_args -4d fake.nii.gz -gsr -nuisance_regression gs
 [ $gsr_in_prefix -eq 1 ]
 parse_args -4d fake.nii.gz -gsr -nuisance_regression dwm,gs,wm
 [ $gsr_in_prefix -eq 1 ]
 [ $nuisance_regressors = "dwm,gs,wm" ]
}


@test "-rmgroup_component" {
 parse_args -4d fake.nii.gz -rmgroup_component test.1d -tr 1
 [ $rmgroup_component_1d == "test.1d" ]
}
@test "fail if -rmgroup_components and -no_warp" {
 run parse_args -4d fake.nii.gz -rmgroup_component test.1d -no_warp
 [ $status -ne 0 ]
}
@test "fail to use motion regressors with no motion" {
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression gs,rx
 [ $status -eq 0 ]
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression gs -no_mc
 [ $status -eq 0 ]
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression gs,rx -no_mc
 [ $status -eq 1 ]
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression gs,drx -no_mc
 [ $status -eq 1 ]
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression 6motion -no_mc
 [ $status -eq 1 ]
 run parse_args -4d fake.nii.gz -gsr -nuisance_regression qtz -no_mc
 [ $status -eq 1 ]
}

