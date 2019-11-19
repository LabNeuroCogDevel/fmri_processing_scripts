#!/usr/bin/env bats
setup() {
 export PATH="$(readlink -f $BATS_TEST_DIRNAME/..):$PATH"
 exampledata=$BATS_TEST_DIRNAME/exampledata/short_func.nii.gz
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD
}
teardown() {
 cd ..
 rm -r $TMPD
 return 0
}
ncol(){ awk '{print NF}' $@ |sort -u|tr -d '\n';}
checkrange(){
 paste <(tr ' ' '\n' < $1)  <(tr ' ' '\n' < $2) | 
 perl -salne '$a+=abs($F[0]-$F[1]); END{$m=$a/$.; $s=$m>$mn && $m<$mx; print("$mn < $m < $mx: ", !$s); exit(!$s)}' -- -mn=$3 -mx=$4
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
