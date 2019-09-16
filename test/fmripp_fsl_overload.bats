#!/usr/bin/env bats

############################
# test motion correct #
############################

testdir=batsofsltemp

mknii() {
 name=$1; shift
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix $name -overwrite  <(echo -e $@)
}

# go into a special temp dir
setup() {
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/overload_fsl

 mkdir $testdir
 cd $testdir
 # create a test dataset
 mknii needle.nii.gz "3 3 3 1"
}

# remove tempdir and contents
teardown() {
 cd ..
 rm -r $testdir
 return 0
}

@test "imfind exists" {
  results=$(imfind needle.nii.gz)
  [ "$results" == "needle.nii.gz" ]

  results=$(imfind needle)
  [ "$results" == "needle.nii.gz" ]

  results=$(imfind needle.nii)
  [ "$results" == "needle.nii.gz" ]

}
@test "imfind can read multiple dots" {
  skip
  imcp neede needle2
  results=$(imfind needle2.dottest)
  [ "$results" == "needle2.dottest.nii.gz" ]

}
@test "imfind dneexists" {
   ! imfind junk

   touch notanii
   ! imfind notanii
}
@test "imfind finds empty nii file" {
   skip
   touch notanii.nii.gz
   ! imfind notanii.nii.gz
}
@test "getout -out" {
  results=$(findfslout -foo bar -out needle haystack -haystack)
  [ $results == "needle.nii.gz" ]
}
@test "getout -o" {
  results=$(findfslout -foo bar -o needle haystack -haystack)
  [ $results == "needle.nii.gz" ]
}

@test "getout last" {
  results=$(findfslout -foo bar foobar -haystack haystack needle)
  [ $results == "needle.nii.gz" ]
}

@test "getout last but other args" {
  skip
  results=$(findfslout -foo bar needle -odt char)
  [ $results == "needle.nii.gz" ]
}


@test "math" {

 fslmaths needle.nii.gz -mul 3 mathout.nii.gz
 # did fslmath work
 [ $(3dBrickStat -non-zero -mean mathout.nii.gz) -eq 3 ]
 # did the overload work
 [ -n "$(3dNotes mathout.nii.gz)" ]
}

@test "mcflirt" {

 mknii 1.nii.gz "3 3 3 1"
 mknii 2.nii.gz "3 3 4 1"
 mknii 3.nii.gz "3 2 3 1"
 mknii 4.nii.gz "3 3 3 1"
 # construct so we will remove up to the odd one out
 3dTcat -prefix func.nii.gz [1-4].nii.gz
 mcflirt -in func.nii.gz -o mc.nii.gz -mats -plots
 [ -r mc.nii.gz ]
 [ -n "$(3dNotes mc.nii.gz)" ]

}
