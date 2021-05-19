#!/usr/bin/env bats

setup() {
  # INPUTDIR="$BATS_TEST_DIRNAME/exampledata/ncanda_fm/"
  # [ ! -d $INPUTDIR ] && skip
  source $BATS_TEST_DIRNAME/../lncdprep
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


  out=$(find_fm 1 mag)
  echo "1: $out"
  [ "$out" == "noses/sub-1/fmap/magnitude1.nii.gz" ]

  rm noses/sub-1/fmap/magnitude1.nii.gz
  run find_fm 1 mag 
  echo "2: $output"
  [ $output == "noses/sub-1/fmap/magnitude.nii.gz" ]
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
