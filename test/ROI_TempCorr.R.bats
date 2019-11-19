#!/usr/bin/env bats


setup() {
  shortrestfile="$BATS_TEST_DIRNAME/inputs/functest.nii.gz"  # 6 time points from a fully preproc'ed WM run1
  mask="$BATS_TEST_DIRNAME/inputs/gm_50mask.nii.gz"
  roi="$BATS_TEST_DIRNAME/inputs/wm_spheres.nii.gz"
  source $BATS_TEST_DIRNAME/test_help.sh # setup_TMPD, teardown_TMPD, ncol, checkrange, last_rowcol
  setup_TMPD # make and go to $TMPD, sets path
}
teardown() {
  teardown_TMPD # remove TMPD unless SAVETEST is not empty
  return 0
}


@test "fail if censor different than roi ts" {
  #SAVETEST=1
  perl -le "print 0 for (1 .. $(3dinfo -nt $shortrestfile))" > cen_good
  (cat cen_good; echo "0") > cen_long
  sed 1d cen_good > cen_short
  run ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -censor cen_long -njobs 1
  [ $status -eq 1 ] 
  run ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -censor cen_short -njobs 1
  echo "$status" >&2
  [ $status -eq 1 ] 

  # make sure censor works at all
  run ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -censor cen_good -njobs 1
  [ $status -eq 0 ] 
}

@test "semi cor fail with bad type" {
  ! ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 10 -pcorr_method semi:pairwiseGK 
}


@test "run with mask" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1
  last_rowcol corr_rois_pearson.txt "33 33"
}

@test "run with 1 job" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1
  last_rowcol corr_rois_pearson.txt "33 33"
}

@test "multiple methods" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -corr_method pearson,kendall
  last_rowcol corr_rois_pearson.txt "33 33"
  last_rowcol corr_rois_kendall.txt "33 33"
}

## Partial correlation
@test "partial cor" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -pcorr_method pearson
  # last_rowcol corr_rois_pearson.txt "33 33"
  last_rowcol corr_rois_pearson_partial.txt "33 102"
}
@test "partial and full" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -corr_method pearson -pcorr_method pearson
  last_rowcol corr_rois_pearson_partial.txt "33 102"
  last_rowcol corr_rois_pearson.txt "33 33"
}
@test "partial -- reset 10 jobs to 1" {
  #SAVETEST=1
  # occastional error:
  #   Error in socketConnection("localhost", port = port, server = TRUE, blocking = TRUE,  :
  #     cannot open the connection
  #   Calls: makePSOCKcluster -> newPSOCKnode -> socketConnection
  #   In addition: Warning message:
  #   In socketConnection("localhost", port = port, server = TRUE, blocking = TRUE,  :
  #     port 11290 cannot be opened

  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 10 -pcorr_method pearson
  last_rowcol corr_rois_pearson.txt "33 33"
}

## Semi
@test "semi cor" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -pcorr_method semi:pearson
  last_rowcol corr_rois_pearson_semipartial.txt "33 102"
}
@test "semi+partial+full cor" {
  ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -pcorr_method semi:pearson,pearson -corr_method pearson
  last_rowcol corr_rois_pearson.txt "33 33"
  last_rowcol corr_rois_pearson_semipartial.txt "33 102"
  last_rowcol corr_rois_pearson_partial.txt "33 102"
}
