#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 [ ! -d $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.3 ] && skip
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/convert_or_use_nii
 source $BATS_TEST_DIRNAME/../preproc_functions/waitforlock
 TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
 cd $TMPD
 cp -r $BATS_TEST_DIRNAME/exampledata/func+fm+ref/gre_field_mapping_96x96.[34]/ ./
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

@test "convert_or_use: simple" {
  ### first try
  # converts
  convert_or_use_nii fm_phase $phased
  # make file
  [ -r fm_phase.nii.gz ]
  # cleared lock
  [ ! -r $phased/.fm_phase_inprogress ]
}
@test "convert_or_use_nii error on glob input" {
  # will not work on globs
  ! convert_or_use_nii fm_phase "$phased/MR*"
  [ ! -r fm_phase.nii.gz ]
  [ ! -r $phased/.fm_phase_inprogress ]
}

@test "convert_or_use wait for lock (hang for 4s)" {
  ### first try
  # converts
  date +%s >> $phased/.fm_phase_inprogress
  (sleep 4s; rm $phased/.fm_phase_inprogress) &
  convert_or_use_nii fm_phase $phased
  # make file
  [ -r fm_phase.nii.gz ]
  # cleared lock
  [ ! -r $phased/.fm_phase_inprogress ]
}

@test "convert_or_use and reuse" {
  #SAVETEST=1
  ### first try
  # converts
  convert_or_use_nii fm_phase $phased
  
  ## already have what we want 
  ## so we dont have to do anything
  tic=$(date +%s)
  convert_or_use_nii fm_phase $phased

  tdiff=$((( $(date +%s) - $tic ))) 
  [ $tdiff -lt 2 ]

  [ ! -r $phased/.fm_phase_inprogress ]
}

@test "convert_or_use link if input exists" {
  #SAVETEST=1
  ### first try
  # converts
  convert_or_use_nii fm_phase $phased

  ## given an identical file, we dont need to do anything
  convert_or_use_nii fm_phase_should_be_a_link fm_phase
  [ -r fm_phase_should_be_a_link.nii.gz ]
  [ -L fm_phase_should_be_a_link.nii.gz ]
  [ ! -r $phased/.fm_phase_should_be_a_link_inprogress ]
}

@test "convert_or_use wont overwrite different files" {
  ### first try
  # converts
  convert_or_use_nii fm_phase $phased
  imcp fm_phase fm_phase_newname
  [  -r fm_phase.json ] && rm fm_phase.json
  # but if given a not identical file, should fail!
  3dNotes -h "make this file a different size" fm_phase_newname.nii.gz
  echo "not overwriting"
  run convert_or_use_nii fm_phase fm_phase_newname
  [ $status -eq 1 ]
  #[ ! -r $phased/.fm_phase_inprogress ]
  return 0
}
@test "convert_or_use sees links" {
  ### first try
  # converts
  convert_or_use_nii fm_phase $phased

  # should know about links
  ln -s fm_phase.nii.gz fm_phase2.nii.gz
  [  -r fm_phase.json ] && rm fm_phase.json

  tic=$(date +%s)
  convert_or_use_nii fm_phase2 $phased

  tdiff=$((( $(date +%s) - $tic ))) 
  [ $tdiff -lt 2 ]
  #[ ! -r $phased/.fm_phase_inprogress ]
}
