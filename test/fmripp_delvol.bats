#!/usr/bin/env bats

############################
# test removing first vols #
############################

testdir=batsremovevol

# go into a special temp dir
setup() {
 source ../preproc_functions/helper_functions
 source ../preproc_functions/remove_first_volumes
 mkdir $testdir
 cd $testdir

 prefix="_" 
 funcFile="tempx5.nii.gz"
 
 # create a test dataset
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix temp.nii.gz -overwrite  <(echo -e "1 1 2 1\n2 2 2 2\n3 1 1 3")
 3dcalc -a temp.nii.gz -expr 'a+10' -prefix temp+10.nii.gz
 # construct so we will remove up to the odd one out
 3dTcat -prefix "${prefix}$funcFile" temp.nii.gz temp.nii.gz temp+10.nii.gz temp.nii.gz temp.nii.gz 


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
@test "take first 2" {
  n_rm_firstvols=2

      nt_pre=$(3dinfo -nt $prefix$funcFile)
   mean0_pre=$(3dBrickStat -mean $prefix$funcFile'[0]')
  prefix_pre=$prefix


  remove_first_volumes

  prefix_post=$prefix

  # func name is what we expect
  [[ $prefix_post == "0$prefix_pre" ]]

  # func has expected num vols
  nt_post=$(3dinfo -nt $prefix$funcFile)
  let "expect = nt_pre - n_rm_firstvols"
  [ $nt_post -eq $expect ]

  mean0_post=$(3dBrickStat -mean $prefix$funcFile'[0]')
  mean1_post=$(3dBrickStat -mean $prefix$funcFile'[1]')
  # that we cut the right spot
  [ $mean0_post != $mean0_pre ] 
  [ $mean1_post == $mean0_pre ] 

}
