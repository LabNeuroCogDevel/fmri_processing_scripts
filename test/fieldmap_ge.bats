#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 INPUTDIR="$BATS_TEST_DIRNAME/exampledata/ncanda_fm/"
 [ ! -d $INPUTDIR ] && skip
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/preprare_fieldmap_ge_complex 
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD
 export logFile="$(pwd)/preprocDistortion.log"
 pwd >&2
 cat > setup <<HEREDOC

 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_bet.nii.gz      ./
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_warpcoef.nii.gz ./
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/template_brain.nii ./

 ext=".nii.gz"
 mprageBet="\$(pwd)/mprage_bet.nii.gz"
 warpCoef="\$(pwd)/mprage_warpcoef.nii.gz"

 qa_imgdir="\$(pwd)/qa_images"
 funcdir="\$(pwd)"

 bbrCapable=1
 func_struct_dof="bbr"
 fmap_struct_dof="bbr"
 sliceMotion4D=1
 mc_first=0
 use_fm=1
 logFile="\$(pwd)/log.txt"
 qa_imglog="\$(pwd)/qalog.txt"

 funcFile="func.nii.gz"
 templateBrain='template_brain'

 funcWarpInterp=spline

 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/fast_wmseg
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_gre_fieldmap
 source $BATS_TEST_DIRNAME/../preproc_functions/waitforlock
 source $BATS_TEST_DIRNAME/../preproc_functions/convert_or_use_nii
 source $BATS_TEST_DIRNAME/../preproc_functions/register_func2struct
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_fieldmap
 source $BATS_TEST_DIRNAME/../preproc_functions/onestep_warp
 source $BATS_TEST_DIRNAME/../preproc_functions/warp_to_template
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_mc_target


 #created by prepare_fieldmap?
 #createBBRFmapWarp 
 
 # needed for onestep warp
 topup_direct=0  
 no_st=0
 st_first=0
 no_warp=0
 despike=0

 # pretend mc_traget is skull stripped
 postSS=mc_target
 preMC=mc_target
 subjMask=mc_target_brain

 ## files
 # get functional data
 3dTcat $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/func.nii.gz'[0-3]' -prefix ./func.nii.gz >&2
 # fake motion correction
 3dTcat func.nii.gz'[0]' -prefix ./mc_target.nii.gz >&2
 # 
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_bet_fast_wmseg.nii.gz ./
 
 # setup directories
 mkdir qa_images
 mkdir transforms
HEREDOC

}

# archive_dcm() { 
# fieldmap_make_rads_per_sec() {
# pointstonii_or_rm(){
# cp_master_ifneeded() {    
# prepare_gre_fieldmap() {
teardown() {
 [ -n "$TMPD" -a -d $TMPD -a -z "$SAVETEST" ] && rm -r $TMPD
 SAVETEST=""
 return 0
}

@test "prepare_ge_fieldmap" {
 skip
 SAVETEST="1"
 # runs fsl's prelude -- slow
 run prepare_fieldmap_ge_complex $INPUTDIR 0
 [ $status -eq 0 ]
 [ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r unwarp/FM_UD_fmap.nii.gz ]
}
@test "prepare_gre_fieldmap" {
 skip
 SAVETEST="1"
 # runs fsl's prelude -- slow
 fm_cfg="pet"
 cp -r $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.[34]/ ./
 magd=$(pwd)/gre_field_mapping_96x96.3
 phased=$(pwd)/gre_field_mapping_96x96.4
 fm_phase="$phased/MR*"
 fm_magnitude="$magd/MR*"
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_gre_fieldmap
 source $BATS_TEST_DIRNAME/../preproc_functions/waitforlock
 source $BATS_TEST_DIRNAME/../preproc_functions/convert_or_use_nii
 run prepare_gre_fieldmap 
 [ $status -eq 0 ]
 [ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r unwarp/FM_UD_fmap.nii.gz ]
}

@test "preprocessDistortion" {

 SAVETEST="1"
 # do fieldmaps
 echo 'unwarpdir="y"' > ge.fm
 fm_cfg="ncanda"
 run $BATS_TEST_DIRNAME/../preprocessDistortion -niidir $INPUTDIR -fm_cfg $fm_cfg -savedir fm -reverse
 [ -r fm/unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r fm/unwarp/FM_UD_fmap.nii.gz ]

 echo setup >&2
 source setup
 echo end_setup >&2

 DISTORTION_DIR="fm/unwarp"
 
 ## run everything else
 run prepare_mc_target
 [ -r mc_target_brain_restore.nii.gz ]
 #[ $status -eq 0 ]

 run prepare_fieldmap
 [ -r transforms/fmap_to_epi.mat ]
 [ -r transforms/func_to_fmap.mat ]
 [ -r unwarp/fmapForBBR.nii.gz ]
 # [ -r transforms/fmap_to_struct_init.mat ]
 #[ $status -eq 0 ]

 register_func2struct >&2
 [ -r func_to_struct.nii.gz ] 
 [ $status -eq 0 ]

 # needs more setup
 onestep_warp standard
 [ $status -eq 0 ]
}
