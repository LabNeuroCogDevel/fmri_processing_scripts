#!/usr/bin/env bats

mknii() {
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix $1 -overwrite  <(echo -e '1 1 1')
 3drefit -xdel $2 -ydel $2 -zdel $2 $1
}
setup() {
  # INPUTDIR="$BATS_TEST_DIRNAME/exampledata/ncanda_fm/"
  # [ ! -d $INPUTDIR ] && skip
  source $BATS_TEST_DIRNAME/../lncdprep # find_fm
  set +u # need this to see errors
  export PATH="$BATS_TEST_DIRNAME:$PATH"
  THISTESTDIR=$(mktemp -d $BATS_TMPDIR/XXX)
  cd $THISTESTDIR

  # without session
  mkdir -p noses/sub-1/{func,fmap}
  touch noses/sub-1/fmap/{abcd,magnitude,magnitude1,phase}.nii.gz
  touch noses/sub-1/func/func.nii.gz

  # with session
  mkdir -p ses/sub-1/ses-2/{func,fmap}
  touch ses/sub-1/ses-2/fmap/{abcd,magnitude,magnitude1,phase}.nii.gz
  touch ses/sub-1/ses-2/func/func.nii.gz
  return 0
}
teardown() {
  cd $BATS_TMPDIR
  rm -r $THISTESTDIR
  return 0
}

@test "find mag or mag1" {
  set +u
  export FMPATT="*.nii.gz"
  export BIDSROOT="noses"


  run find_fm 1 mag
  echo "1: $output"
  [ "$output" == "noses/sub-1/fmap/magnitude1.nii.gz" ]
  rm noses/sub-1/fmap/magnitude1.nii.gz

  run find_fm 1 mag 
  echo "2: $output"
  [ "$output" == "noses/sub-1/fmap/magnitude.nii.gz" ]
}

@test "find phase" {
  set +u
  export FMPATT="*.nii.gz"
  export BIDSROOT="noses"
  out=$(find_fm 1 phase)
  echo "phase: $out"
  [ "$out" == "noses/sub-1/fmap/phase.nii.gz" ]
}

@test "find w/o ses" {
 BIDSROOT="noses"
 out=$(find_func 3)
 echo "subjid: '$out'"
 [ "$out" == 1 ]
}

@test "find w/ses" {
 BIDSROOT="ses"
 out=$(find_func 4)
 echo "subjid: '$out'"
 [ "$out" == 1/ses-2 ]
}

@test "bids in to deriv func" {
  BIDSROOT="a/b/c"
  output=$(bids_to_deriv_dir "a/b/c/sub-1/ses-2/func/sub-1_ses-2_task-rest_run-1_bold.nii.gz" "derive")
  echo "$output" >&2
  [[ "$output" = "derive/sub-1/ses-2/task-rest_run-1_bold" ]]
}
@test "bids in to deriv func noses" {
  BIDSROOT="a/b/c"
  output=$(bids_to_deriv_dir "a/b/c/sub-1/func/sub-1_task-rest_run-1_bold.nii.gz" "derive")
  echo "$output" >&2
  [[ "$output" = "derive/sub-1/task-rest_run-1_bold" ]]
}
@test "bids in to deriv anat" {
  BIDSROOT="a/b/c"
  output=$(bids_to_deriv_dir "a/b/c/sub-1/ses-2/anat/sub-1_ses-2_T1w.nii.gz" "derive")
  echo "$output" >&2
  [[ "$output" = "derive/sub-1/ses-2/T1w" ]]
}

@test "old derive" {
  BIDSROOT="b"
  OUTDIR="d"
  T1DNAME="T1"; T2ROOT="bold";
  # bold: $OUTPUTDIR/$T2ROOT/11757/sub-11757_task-SOA_bold 
  # t1w : t1out="$OUTDIR/$T1DNAME/$id" #pre-20210519
  run bids_to_old_deriv b/sub-11757/func/sub-11757_task-SOA_bold.nii.gz
  echo $output >&2
  [[ $output = "d/bold/11757/sub-11757_task-SOA_bold" ]]

  run bids_to_old_deriv b/sub-11757/ses-X/func/sub-11757_ses-X_task-SOA_bold.nii.gz
  echo $output >&2
  [[ $output = "d/bold/11757/ses-X/sub-11757_ses-X_task-SOA_bold" ]]

  run bids_to_old_deriv b/sub-11757/anat/sub-11757_T1w.nii.gz
  echo $output >&2
  [[ $output = "d/T1/11757" ]]

  run bids_to_old_deriv b/sub-11757/ses-X/anat/sub-11757_ses-X_T1w.nii.gz
  echo $output >&2
  [[ $output = "d/T1/11757/ses-X" ]]
}


@test "parseargs:template" {
    # default
    echo "def temp: '$T1TEMPLATE'" >&2
    [[ $T1TEMPLATE == "MNI_2mm" ]]

    parse_args BIDS DERIVE --task
    echo "stll def temp: '$T1TEMPLATE'" >&2
    [[ $T1TEMPLATE == "MNI_2mm" ]]

    parse_args BIDS DERVE --task --ppmprage_args "-r 1YO_2mm"
    echo "change def temp: '$T1TEMPLATE'" >&2
    [[ $T1TEMPLATE == "1YO_2mm" ]]
    
}

@test "template_string" {
 run t1_tmpl_str MNI_2mm
 echo "$output" >&2
 [[ $output == "tmpl-MNI_res-2mm" ]]
 [[ $(t1_tmpl_str MNI_FSL_2mm) == "tmpl-MNIFSL_res-2mm" ]]
}

@test "t2templatechecks" {
  mknii func_2.nii.gz 2
  mknii func_2.3.nii.gz 2.3
  mknii func_3.nii.gz 3

  run t2template func_2.nii.gz
  echo "normal: $output" >&2
  [[ $status -eq 0 ]]
  [[ $output == "-template_brain MNI_2mm" ]]
  
  # stardard bump to 3mm fail if too big
  run t2template func_3.nii.gz
  echo "3: '$output' $status" >&2
  [[ $status -eq 0 ]]
  [[ $output == "-template_brain MNI_3mm" ]]

  # stardard bump to 3mm fail if too big
  run t2template func_2.3.nii.gz
  echo "2.3: '$output' $status" >&2
  [[ $status -eq 0 ]]
  [[ $output == "-template_brain MNI_2.3mm" ]]
  
  #but not if we have no warp
  ARGS="-no_warp"
  run t2template func_3.nii.gz
  echo "no warp: '$output' $status" >&2
  [[ $status -eq 0 ]]
  [[ $output == "" ]]
  
  # or if we force
  ARGS="-template_brain MNI_2mm"
  run t2template func_3.nii.gz
  echo "force template: '$output' $status" >&2
  [[ $status -eq 0 ]]
  [[ $output == "$ARGS" ]]

  # fail if templates mismatch
  ARGS="-template_brain MNI_FSL_3mm"
  run t2template func_3.nii.gz
  echo "mismatch template: '$output' $status" >&2
  [[ $output =~ mismatch ]]
  [[ $status -gt 0 ]]
  
  # fail when non MNI is too big
  # N.B. could also fail b/c template mismatch
  T1TEMPLATE="1YO_2mm"
  ARGS=""
  run t2template func_3.nii.gz
  echo "too big: '$output' $status" >&2
  [[ $output =~ different ]]
  [[ $status -gt 0 ]]
}

