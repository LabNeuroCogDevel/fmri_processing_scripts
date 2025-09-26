#!/usr/bin/env bats
setup() {
 [ -n "$TEST_SKIP_R" ] && skip "TEST_SKIP_R set, not running test"
 export PATH="$(readlink -f $BATS_TEST_DIRNAME/..):$PATH"
 exampledata=$BATS_TEST_DIRNAME/exampledata/short_func.nii.gz
 source $BATS_TEST_DIRNAME/test_help.sh # setup_TMPD, teardown_TMPD, ncol, checkrange
 setup_TMPD # make and go to $TMPD
}
teardown() {
 teardown_TMPD # remove TMPD unless SAVETEST is not empty
 return 0
}

# testing because fsl6 caused issue
@test "1dbptf" {
   # 192 row of 16 random regressors
   perl -le 'BEGIN{srand(1)} print join " ", map {rand} (1..16) for (1..192)' > unfilt.txt

   # as used for -hp (task) data in preprocessFunctaion : preproc_functions/nuisance_regression
   1dbptf -matrix unfilt.txt -tr 2.18 -time_along_rows -out_file reg.txt -hp_volumes 16.9851

   # input and output have the same shape
   [ $(wc -l < unfilt.txt) -eq $(wc -l < reg.txt) ]
   [ $(ncol reg.txt unfilt.txt) -eq 16 ]

   # changes, but not too much
   checkrange unfilt.txt reg.txt 0.001 .1
}
