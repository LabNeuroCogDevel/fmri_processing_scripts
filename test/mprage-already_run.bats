#!/usr/bin/env bats
# also see fmripp_parseargs.bats:"default smoothing"
mknii_dim(){
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix $1 -overwrite  <(echo -e '1 1 1')
}
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/parse_args # parse_args
 source ../preproc_functions/helper_functions # rel
 source ../preproc_functions/mprage_utils
 MYTEMP=$(mktemp -d $BATS_TMPDIR/bats_smooth_XXX)
 cd $MYTEMP
 logFile="test.log"
}
teardown(){ 
 [ -n "$MYTEMP" -a -d "$MYTEMP" ] && rm -r $MYTEMP || :
}

@test current_step_file {
    T1=mprage
    [ $(current_step_file) == "$T1.nii.gz" ]
    echo > .cur_step
    [ $(current_step_file) == "$T1.nii.gz" ]
    echo "xyz" > .cur_step
    [ $(current_step_file) == "${T1}_xyz.nii.gz" ]
    echo "abc" > .cur_step
    [ $(current_step_file) == "${T1}_abc.nii.gz" ]
}
@test cur_and_next {
    T1=mprage
    read pre out < <(cur_and_next "abc")
    echo "pre:'$pre' out:'$out'" >&2
    [ $pre == "mprage.nii.gz" ]
    [ $out == "mprage_abc.nii.gz" ]
    [ -r .cur_step ]
    [ $(cat .cur_step) == "abc" ]

    read pre out < <(cur_and_next "xyz")
    echo "pre:'$pre' out:'$out'" >&2
    [ $(cat .cur_step) == "abc_xyz" ]
    [ $pre == "mprage_abc.nii.gz" ]
    [ $out == "mprage_abc_xyz.nii.gz" ]
}

@test reorient {
    T1=mprage
    nifti=$T1.nii.gz
    mknii_dim $nifti
    reorient
    [ $(cat .cur_step) == "reorient" ]
    [ -r mprage_reorient.nii.gz ]
}

@test unifize {
    T1=mprage
    mknii_dim $T1.nii.gz
    unifize
    [ $(cat .cur_step) == "unifize" ]
    [ -r mprage_unifize.nii.gz ]
}
@test reorient-unifize {
    T1=mprage
    nifti=$T1.nii.gz
    mknii_dim $nifti
    reorient
    unifize
    [ $(cat .cur_step) == "reorient_unifize" ]
    [ -r mprage_reorient_unifize.nii.gz ]
}

@test backup_orig {
   skip
   # TODO: write test

   T1=mprage
   nifti=$T1.nii.gz
   mknii_dim $nifti
   backup_original "$T1" "$nifti" # get back to original or make a copy so we can later
}
