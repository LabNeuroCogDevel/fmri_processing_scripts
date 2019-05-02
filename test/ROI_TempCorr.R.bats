#!/usr/bin/env bats

scriptdir=$(cd $(pwd)/..;pwd)
shortrestfile="$(pwd)/inputs/functest.nii.gz"  # 6 time points from a fully preproc'ed WM run1
mask="$(pwd)/inputs/gm_50mask.nii.gz"
roi="$(pwd)/inputs/wm_spheres.nii.gz"

setup() {
  TDIR=$(mktemp -d $BATS_TMPDIR/roitemp-XXXX)
  cd $TDIR
  pwd >&2

}


# remove cor text file a the end
teardown() {
  cd -
  rm -r "$TDIR"
  return 0
}


@test "run with mask" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
}

@test "run with 1 job" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
}

@test "multiple methods" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -corr_method pearson,kendall
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
  results=$(awk 'END{print NR,NF}' corr_rois_kendall.txt)
  [ "$results" == "33 33" ]
}

## Partial correlation
@test "partial cor" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -pcorr_method pearson
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
}
@test "partial and full" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -corr_method pearson -pcorr_method pearson
  results=$(awk 'END{print NR,NF}' corr_rois_pearson_partial.txt)
  [ "$results" == "33 102" ]
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
}
@test "partial -- reset 10 jobs to 1" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 10 -pcorr_method pearson
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
}

## Semi
@test "semi cor" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -pcorr_method semi:pearson
  results=$(awk 'END{print NR,NF}' corr_rois_pearson_semipartial.txt)
  [ "$results" == "33 102" ]
}
@test "semi+partial+full cor" {
  $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -pcorr_method semi:pearson,pearson -corr_method pearson
  results=$(awk 'END{print NR,NF}' corr_rois_pearson.txt)
  [ "$results" == "33 33" ]
  results=$(awk 'END{print NR,NF}' corr_rois_pearson_partial.txt)
  [ "$results" == "33 102" ]
  results=$(awk 'END{print NR,NF}' corr_rois_pearson_semipartial.txt)
  [ "$results" == "33 102" ]
}

@test "semi cor fail with bad type" {
  ! $scriptdir/ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 10 -pcorr_method semi:pairwiseGK 
}


