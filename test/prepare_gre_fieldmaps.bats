#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 [ ! -d $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.3 ] && skip
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD
 cp -r $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.[34]/ ./
 cat > sourceme <<HEREDOC
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_gre_fieldmap
 source $BATS_TEST_DIRNAME/../preproc_functions/waitforlock
 source $BATS_TEST_DIRNAME/../preproc_functions/convert_or_use_nii
 magd=$(pwd)/gre_field_mapping_96x96.3
 phased=$(pwd)/gre_field_mapping_96x96.4
HEREDOC

 source sourceme

 # done in check_requreiments
 command -v dcm2niix >/dev/null 2>&1 && have_dcm2niix=1 || have_dcm2niix=0
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

@test "prepare_gre_fieldmap" {
 #SAVETEST=1
 #pwd >&2
 cat >> sourceme <<HEREDOC
 fm_cfg="pet"
 fm_phase="$phased/MR*"
 fm_magnitude="$magd/MR*"
HEREDOC
 source sourceme
 run prepare_gre_fieldmap 
 [ $status -eq 0 ]
 [ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r unwarp/FM_UD_fmap.nii.gz ]
}

@test "prepare mag" {
 run prepare_gre_fieldmap_mag $magd "MR*" 
 [ $status -eq 0 ] 
 [ -r .fieldmap_magnitude ]
 [ -r $magd/.fieldmap_magnitude ]
 [ -r $magd/echo1/fm_magnitude_echo1_dicom.tar.gz ]
 [ -z "$(find $magd -iname 'MR*')" ]
}

@test "prepare phase" {
 run prepare_gre_fieldmap_phase $phased "MR*"
 [ $status -eq 0 ] 
 [ -r .fieldmap_phase ]
 [ -r $phased/.fieldmap_phase ]
 [ -r $phased/fm_phase_dicom.tar.gz ]
 [ -z "$(find $phased -iname 'MR*')" ]
}

@test "swap" {
 ! phase_mag_need_swap "$phased/MR*" "$magd/MR*" 
   phase_mag_need_swap "$magd/MR*" "$phased/MR*" 
}

@test "ncanda nii style" {
 pwd >&2
 dcm2niix -o ./ -f mag $magd
 dcm2niix -o ./ -f phase $phased
 fm_cfg="pet"
 run prepare_gre_fieldmap mag_e1.nii.gz phase*.nii.gz
 [ $status -eq 0 ] 
 [ -r unwarp/FM_UD_fmap_mag.nii.gz ]
 [ -r unwarp/FM_UD_fmap.nii.gz ]
}
