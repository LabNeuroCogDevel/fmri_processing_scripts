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

@test zcut_4 {
    T1=mprage
    echo reorient > .cur_step
    mknii_dim mprage_reorient.nii.gz
    cut_zindex 4

    [ $(cat .cur_step) == "reorient_zindex-4" ]
    [ -r mprage_reorient_zindex-4.nii.gz ]
    # max was 6, now have only slices 4 & 5 (0-indexed). should be dim size of 2
    [ $(3dinfo -nk mprage_reorient_zindex-4.nii.gz) -eq 2 ]
}

@test zcut_1-4 {
    T1=mprage
    echo reorient > .cur_step
    mknii_dim mprage_reorient.nii.gz
    cut_zindex 1-4

    [ $(cat .cur_step) == "reorient_zindex-1-4" ]
    [ -r mprage_reorient_zindex-1-4.nii.gz ]
    [ $(3dinfo -nk mprage_reorient_zindex-1-4.nii.gz) -eq 4 ]
}
