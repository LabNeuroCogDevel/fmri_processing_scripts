#!/usr/bin/env bats

############################
# test motion correct #
############################

testdir=batsmctemp

mknii() {
 name=$1; shift
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix $name -overwrite  <(echo -e $@)
}

# go into a special temp dir
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/helper_functions
 source ../preproc_functions/correct_motion

 mkdir $testdir
 cd $testdir

 ext=.nii.gz
 prefix="_" 
 funcFile="testmc.nii.gz"
 funcNifti=$funcFile

 
 # create a test dataset
 mknii 1.nii.gz "3 3 3 1"
 mknii 2.nii.gz "3 3 4 1"
 mknii 3.nii.gz "3 2 3 1"
 mknii 4.nii.gz "3 3 3 1"
 # construct so we will remove up to the odd one out
 3dTcat -prefix "${prefix}$funcFile" [1-4].nii.gz


}

# remove tempdir and contents
teardown() {
 cd ..
 rm -r $testdir
 return 0
}


# test that 
#  - prefix is update
#  - number of volumes is changed
#  - odd ball volume is now first
@test "mcflirt mean default" {
 ref_vol=''
 needToComputeMCStat=""
 correct_motion 
 [ $ref_vol == 'mean' ]
}
@test "mcflirt mean" {
 ref_vol='mean'
 correct_motion 
 #rsync -r . ../bak/mean
}
@test "mcflirt median" {
 ref_vol='median'
 correct_motion 
 #rsync -r . ../bak/median
}
@test "mcflirt second vol" {
 ref_vol=2
 correct_motion 
 #rsync -r . ../bak/2
}
@test "mcflirt bad refvol" {
 ref_vol='bad'
 ! correct_motion 
}
