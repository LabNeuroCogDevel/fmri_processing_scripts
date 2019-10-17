#!/usr/bin/env bats

#########################
# test wavlet despiking #
#########################

testdir=slicemotion4d

# go into a special temp dir
setup() {
 cd $BATS_TEST_DIRNAME

 exampledata=exampledata/short_func.nii.gz
 [ ! -r $exampledata ] && skip
 exampledata=$(readlink -f $exampledata)

 mkdir $testdir
 cd $testdir
 ln -s $exampledata  example.nii.gz
 return 0
}

# remove tempdir and contents
teardown() {
 cd ..
 rm -r $testdir
 return 0
}


@test "run slicemotion4d" {
 ../../sliceMotion4d -i example.nii.gz --siemens --slice_times interleaved --prefix mt_ -t 1.5
 [ -r mt_example.nii.gz ]

 # check that we did something to the data
 res="$(3dBrickStat -non-zero -mean -slow "3dcalc( -a mt_example.nii.gz -b example.nii.gz -expr a-b )")"
 [[ "$results" != "-nan" ]]

}

# only run if we dont have matlab and do have octave
@test "py2 and py3 have same results" {
 [ ! -r ../../sliceMotion4d_py2 ] && skip
 ../../sliceMotion4d -i example.nii.gz --siemens --slice_times interleaved --prefix mt_ -t 1.5
 ../../sliceMotion4d_py2 -i example.nii.gz --siemens --slice_times interleaved --prefix mt2_ -t 1.5
 results=$(3dBrickStat -non-zero -mean -slow "3dcalc( -a mt_example.nii.gz -b mt2_example.nii.gz -expr a-b )")

 [[ "$results" == "-nan" ]]
}
