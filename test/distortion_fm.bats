#!/usr/bin/env bats

#####################################
# stand alone distortion correction #
#####################################

# source the functions we want to test
setup() {
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD

 # put this in a file so we can go back to it when SAVEDIR=1
cat > thingstosource <<EOF
 BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME"
 BATS_TMPDIR="$BATS_TMPDIR"

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
 func_struct_dof="bbr"
 fmap_struct_dof="bbr"
 sliceMotion4D=1
 mc_first=0
 use_fm=1
 logFile="$(pwd)/log.txt"
 qa_imglog="$(pwd)/qalog.txt"

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

EOF


 # get fieldmaps
 cp -r $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.[34]/ ./
 
 # get t1 and warps
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_bet.nii.gz      ./
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/mprage_warpcoef.nii.gz ./
 ln -s $BATS_TEST_DIRNAME/exampledata/func+fm+ref/nii/template_brain.nii ./

 # bring in all the settings and functions
 source thingstosource

}

teardown() {
 [ -n "$TMPD" -a -d $TMPD -a -z "$SAVETEST" ] && rm -r $TMPD
 [ -n "$SAVETEST" ] && pwd >&2 && echo "source thingstosource" >&2
 SAVETEST=""
 return 0
}


@test "preprocessDistortion (see also prepare_gre_fieldmaps.bats) no bbr for faster runtime" {
 echo "bbrCapable=''" >> thingstosource
 echo "func_struct_dof=''" >> thingstosource
 echo "fmap_struct_dof=''" >> thingstosource

 
 source thingstosource
 #SAVETEST=1
 run $BATS_TEST_DIRNAME/../preprocessDistortion -phasedir $phased -magdir $magd -fm_cfg $fm_cfg
 [ $status -eq 0 ]
 [ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r unwarp/FM_UD_fmap.nii.gz ]

}


@test "preprocessDistortion gre + register_func2struct + onestep_warp (slow!)" {
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
 mkdir fm
 cd fm
 run $BATS_TEST_DIRNAME/../preprocessDistortion -phasedir $phased -magdir $magd -fm_cfg $fm_cfg
 [ $status -eq 0 ]
 [ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r unwarp/FM_UD_fmap.nii.gz ]
 cd ..

 # N.B. continuing on, scripts are useing distoration dir, already set as
 # DISTORTION_DIR="fm/unwarp"
 
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

