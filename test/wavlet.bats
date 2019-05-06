#!/usr/bin/env bats

#########################
# test wavlet despiking #
#########################

testdir=wavlet_tests

mknii() {
 name=$1; shift
 3dUndump -overwrite -dimen 2 2 2 -srad 1 -ijk  -prefix $name -overwrite  <(echo -e $@)
}

# go into a special temp dir
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/helper_functions
 source ../preproc_functions/despike_timeseries
 export\
    despike=1 waveletDespike=1 waveletM1000=0 \
    postSS=test ext=.nii.gz MATLAB_RAM_limit=3 \
    waveletThreshold=10 scriptDir=$(cd ../;pwd) \
    funcFile=_matlab

 mkdir $testdir
 cd $testdir

 # # create a test dataset
 # mknii 1.nii.gz "0 0 0 1\n0 1 0 9\n1 0 0 2\n1 1 0 1"
 # mknii 2.nii.gz "0 0 0 2\n0 1 0 8\n1 0 0 1\n1 1 0 1"
 # mknii 3.nii.gz "0 0 0 9\n0 1 0 1\n1 0 0 5\n1 1 0 5"
 # mknii 4.nii.gz "0 0 0 4\n0 1 0 7\n1 0 0 1\n1 1 0 1"
 # mknii 5.nii.gz "0 0 0 5\n0 1 0 6\n1 0 0 2\n1 1 0 1"
 # 3dTcat -overwrite -prefix "test.nii.gz" [1-4].nii.gz
 3dTcat ../exampledata/func+fm+ref/nii/func.nii.gz'[0..4]' -prefix test.nii.gz
 return 0

}

# remove tempdir and contents
teardown() {
 cd ..
 rm -r $testdir
 return 0
}

bs() { 3dBrickStat -slow $1 $2; }
gt() {  perl -e "exit(1) if $(bs $1 $2) <= $(bs $1 $3)";  }

@test "matlab wavlet lower max/stdev" {
 ! command -v matlab && skip
 despike_timeseries

 gt -max   predespike.nii.gz d_matlab.nii.gz
 gt -stdev predespike.nii.gz d_matlab.nii.gz 
}

# only run if we dont have matlab and do have octave
@test "octave wavlet lower max/stdev" {
 # command -v matlab && skip # could skip if it worked in matlab
 ! command -v octave && skip
 export USE_OCTAVE=yes preDiespike=octave funcFile=_octave prefix=""
 despike_timeseries

 gt -max   predespike.nii.gz d_octave.nii.gz
 gt -stdev predespike.nii.gz d_octave.nii.gz 
}

# run if we have both matlab and octave
@test "matlab == octave" {
 ! command -v matlab && skip
 ! command -v octave && skip
 # run with matlab
 despike_timeseries

 # setup for octave run
 3dcopy -overwrite test.nii.gz octave.nii.gz
 rm predespike.nii.gz .despike_complete
 export USE_OCTAVE=yes preDiespike=octave funcFile=_octave prefix=""

 despike_timeseries

 3dcalc -a d_octave.nii.gz -b d_matlab.nii.gz -expr 'abs(a-b)' -prefix diff.nii.gz
 3dBrickStat diff.nii.gz
 perl -e "exit(1) if $(bs -max diff.nii.gz) != 0"
}
