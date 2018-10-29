#!/usr/bin/env bats

####################
# test arg parsing #
####################

export testdir=batsparseargstest
export funcdir=./
# go into a special temp dir
setup() {
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

# physio usage
@test "physio input: expected" {
 touch junk.txt junk.puls junk.json
 mkdir mrdir
 run parse_args -4d fake.nii.gz -physio_card junk.puls -physio_resp junk.txt -physio_func_info junk.json
 [ $status -eq 0 ]
 run parse_args -4d fake.nii.gz -physio_card junk.puls -physio_resp junk.txt -physio_func_info mrdir 
 [ $status -eq 0 ]
}
@test "physio input: fails" {
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

# check setting trunc
@test "trunc == 4" {
 parse_args -trunc 4 -no_warp
 [ $n_rm_firstvols -eq 4 ]
 return 0
}

# we set autocorr_with_basis with rmautocorr switch
@test "with rmautocorr" {
 parse_args -4d fake.nii.gz -rmautocorr  -bandpass_filter 0.009 .08
 [ $autocorr_with_basis -eq 1 ]
 [ $funcFile == "fake" ]

}

@test "rmautocor and nuisance" {
 parse_args -4d fake.nii.gz -rmautocorr  -bandpass_filter 0.009 .08 -nuisance_regression 6motion
 [ $autocorr_with_basis -eq 1 ]
 [ $funcFile == "fake" ]
}

# this restraint has been removed! (when, why?, noted after the fact on 20181029) 
# @test "fail with rmautocorr and no bandpass_filter" {
#  run parse_args -4d fake.nii.gz -rmautocorr  
#  [ $status -ne 0 ]
# }

@test "default without rmautocorr" {
 parse_args -4d fake.nii.gz
 [ $autocorr_with_basis -eq 0 ]
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

