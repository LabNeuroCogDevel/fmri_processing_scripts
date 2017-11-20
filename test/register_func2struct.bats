#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD

 # put this in a file so we can go back to it when SAVEDIR=1
cat > thingstosource <<EOF
 fm_cfg="pet"
 DISTORTION_DIR="fm/unwarp"
 magd=$(pwd)/gre_field_mapping_96x96.3
 phased=$(pwd)/gre_field_mapping_96x96.4

 ext=".nii.gz"
 mprageBet="$(pwd)/mprage_bet.nii.gz"
 warpCoef="$(pwd)/mprage_warpcoef.nii.gz"

 qa_imgdir="$(pwd)/qa_images"
 funcdir="$(pwd)"

 bbrCapable=1
 funcStructFlirtDOF="bbr"
 sliceMotion4D=1
 mc_first=0
 use_fm=1
 logFile="$(pwd)/log"

 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/fast_wmseg
 source $BATS_TEST_DIRNAME/../preproc_functions/convert_or_use_nii
 source $BATS_TEST_DIRNAME/../preproc_functions/register_func2struct
 source $BATS_TEST_DIRNAME/../preproc_functions/onestep_warp
 source $BATS_TEST_DIRNAME/../preproc_functions/warp_to_template
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_mc_target

 find_and_source_fmconfig "$fm_cfg"

EOF


 # get fieldmaps
 # sou
 # sou
 cp -r $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.[34]/ ./
 cp -r $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/unwarp      ./
 
 # get t1 and warps
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_bet.nii.gz      ./
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_warpcoef.nii.gz ./

 # bring in all the settings and functions
 source thingstosource

}

teardown() {
 [ -n "$TMPD" -a -d $TMPD -a -z "$SAVETEST" ] && rm -r $TMPD
 [ -n "$SAVETEST" ] && pwd >&2 && echo "source thingstosource" >&2
 SAVETEST=""
 return 0
}


@test "register_func2struct (copied fast output to speedup)" {
 SAVETEST=1

 ## files
 # get functional data
 3dTcat $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/func.nii.gz'[0-3]' -prefix ./func.nii.gz >&2
 # fake motion correction
 3dTcat func.nii.gz'[0]' -prefix ./mc_target.nii.gz >&2
 # 
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_bet_fast_wmseg.nii.gz ./
 
 # setup directories
 mkdir $qa_imgdir
 mkdir transforms

 ## run fieldmaps
 #[ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 #[ -r unwarp/FM_UD_fmap.nii.gz ]

 echo "runnign reg" >&2
 register_func2struct >&2
 echo "ran reg" >&2
 [ -r func_to_struct.nii.gz ] 
 [ $status -eq 0 ]


}

