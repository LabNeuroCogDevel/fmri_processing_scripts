#!/usr/bin/env bats

# create a motion.par file
setup() {
 export TESTDIR=$(mktemp -d $BATS_TMPDIR/resample_XXX)
 cd $TESTDIR
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/nuisance_regression

  export MPRAGE="$BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_bet.nii.gz"
}

# remove cor text file a the end
teardown() {
 cd ..
 [ -n "$TESTDIR" -a -d "$TESTDIR" ] && rm -r "$TESTDIR"
 return 0
}

@test "resample_or_keep: keep" {
   run resample_or_keep "$MPRAGE" "$MPRAGE"
   echo "using '$MPRAGE', output: '$output'"
   echo "have: $(ls)"
   # no change
   [[ $output == "$MPRAGE" ]]
   [ ! -r $(basename $MPRAGE .nii.gz)_resampled.nii.gz ]
}

@test "resample_or_keep: resample" {
   out_file=$(basename $MPRAGE .nii.gz)_resampled.nii.gz
   3dresample -prefix lowres.nii.gz -dxyz 4 4 4 -input $MPRAGE
   # creates new file in cwd
   echo "expect: '$out_file'"               # debug
   res=$(resample_or_keep lowres.nii.gz $MPRAGE)
   ls                                       # debug
   echo "output: $res"                      # debug
   [[ "$res" == "$out_file" ]]
   [ -r $out_file ]
   3dinfo -ad3 -n4 -extent -iname lowres.nii.gz $out_file # debug
   3dinfo -header_line -same_all_grid -iname lowres.nii.gz $out_file # debug
   grid_matches "lowres.nii.gz" "$out_file"
}


