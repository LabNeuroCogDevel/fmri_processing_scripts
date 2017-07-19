#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_gre_fieldmap
 source $BATS_TEST_DIRNAME/../preproc_functions/waitforlock
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD
 cp -r $BATS_TEST_DIRNAME/exampledata/gre_fm/gre_field_mapping_96x96.[34]/ ./
 magd=$(pwd)/gre_field_mapping_96x96.3
 phased=$(pwd)/gre_field_mapping_96x96.4
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

 fm_cfg="pet"
 fm_phase="$phased/MR*"
 fm_magnitude="$magd/MR*"
 prepare_gre_fieldmap 
 #[ $status -eq 0 ]

}
@test "prepare mag" {
 #SAVETEST=1
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

