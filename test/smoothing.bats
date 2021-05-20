#!/usr/bin/env bats
# also see fmripp_parseargs.bats:"default smoothing"
mknii_dim(){
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix $1 -overwrite  <(echo -e '1 1 1')
 3drefit -xdel $2 -ydel $2 -zdel $2 $1
}
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/parse_args # get_default_smoothing
 source ../preproc_functions/spatial_smooth # spatial_smooth
 source ../preproc_functions/template_funcs # find_mprage_warpj
 source ../preproc_functions/helper_functions # needed for others
 MYTEMP=$(mktemp -d $BATS_TMPDIR/bats_smooth_XXX)
 cd $MYTEMP
 logFile="smoothing.log"
# SPATIALSMOOTH_GLOBALS=(prefix funcFile smoothing_suffix no_smooth smoothing_kernel smoother susan_thresh p_2 median_intensity sigma)

 ext=.nii.gz
 prefix="_" 
 funcFile="testmc.nii.gz"
 funcNifti=$funcFile
}
teardown(){ 
 [ -n "$MYTEMP" -a -d "$MYTEMP" ] && rm -r $MYTEMP || :
}

@test default_smoother_3is5 {
    mknii_dim func.nii.gz 3 
    local smooth_k=$(get_default_smoothing func.nii.gz)

    [[ "$smooth_k" == 5 ]]
}

@test default_smoother_2is4 {
    mknii_dim func.nii.gz 2
    local smooth_k=$(get_default_smoothing func.nii.gz)
    [[ "$smooth_k" == 4 ]]
}

@test defaultsmooth_MNI_2.3mm {
    local smooth_k=$(get_default_smoothing MNI_2.3mm)
    [[ "$smooth_k" == 5 ]]
}
@test defaultsmooth_MNI_3mm {
    local smooth_k=$(get_default_smoothing MNI_3mm)
    [[ "$smooth_k" == 5 ]]
}
@test defaultsmooth_2mm {
    local smooth_k=$(get_default_smoothing MNI_FSL_2mm)
    [[ "$smooth_k" == 4 ]]
}
