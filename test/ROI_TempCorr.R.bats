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

@test "warn about bad voxel unless -no_badmsg" {
  # put a whole at roi#21 voxel ijk 32,50,38 -- not actually needed -- func has holes elsewhere already
  #   ROI 3: 30 voxels had bad time series (e.g., constant) and were removed prior to ROI averaging.
  #   ROI 4: 25 voxels had bad time series (e.g., constant) and were removed prior to ROI averaging.
  #   ROI 12: 4 voxels had bad time series (e.g., constant) and were removed prior to ROI averaging.
  #   ROI 19: 3 voxels had bad time series (e.g., constant) and were removed prior to ROI averaging.
  3dcalc -f $shortrestfile -expr 'f*iszero(iszero(i-32)*iszero(j-50)*iszero(k-38))' -overwrite -prefix whole@32,50,38.nii.gz
  run ROI_TempCorr.R -ts whole@32,50,38.nii.gz -rois $roi -njobs 1
  [ $status -eq 0 ] 
  [[ $output =~ 'had bad time series' ]]
  run ROI_TempCorr.R -ts whole@32,50,38.nii.gz -rois $roi -njobs 1 -no_badmsg
  [ $status -eq 0 ] 
  ! [[ $output =~ 'had bad time series' ]]
}

@test "-write_header" {
  run ROI_TempCorr.R -ts $shortrestfile -rois $roi -njobs 1 -roi_vals 4,3 -write_header 1
  [ $status -eq 0 ] 
  [ -r ./corr_rois_pearson.txt ]
  head -n1  ./corr_rois_pearson.txt | grep roi3

  run ROI_TempCorr.R -ts $shortrestfile -rois $roi -njobs 1 -roi_vals 4,3 
  [ $status -eq 0 ] 
  [ -r ./corr_rois_pearson.txt ]
  head -n1  ./corr_rois_pearson.txt | grep -v roi3
}

@test "-roi_vals subsets write_header" {
  run ROI_TempCorr.R -ts $shortrestfile -rois $roi -njobs 1 -roi_vals 4,3 -write_header 1
  [ $status -eq 0 ] 
  [ -r ./corr_rois_pearson.txt ]
  head -n1  ./corr_rois_pearson.txt | grep roi3
  head -n1  ./corr_rois_pearson.txt |  grep -v roi2
}
@test "warn about -roi_vals outside of mask" {
  run ROI_TempCorr.R -ts $shortrestfile -rois $roi -njobs 1 -roi_vals 4,100000
  [ $status -eq 0 ] 
  [[ $output =~ 'Not all -roi_vals are in roimask'.*100000 ]]
  # NB. will not have reasonable column names! BUG TODO. 
}

@test "warn about bad rois unless -no_badmsg" {
  3dUndump -overwrite -prefix bad_roi.nii.gz -master $shortrestfile <(echo -e "10 10 10 1 10\n30 30 30 2 10")
  run ROI_TempCorr.R -ts $shortrestfile -rois bad_roi.nii.gz -njobs 1
  [ $status -eq 0 ] 
  [[ $output =~ 'fewer than 5 voxel' ]]
  run ROI_TempCorr.R -ts $shortrestfile -rois bad_roi.nii.gz -njobs 1 -no_badmsg
  [ $status -eq 0 ] 
  ! [[ $output =~ 'fewer than 5 voxel' ]]
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

@test "tempcorr_help" {
  run ROI_TempCorr.R -help
  [[ $output =~ ROI_TempCorr ]]
  [ $status -eq 0 ]
}

@test "tempcorr_ts+-" {
  run ROI_TempCorr.R -ts $shortrestfile -ts+ $shortrestfile -rois $roi
  # if just shortrestfile without ts+ would have 6 timeponts:
  # ...      4D timeseries size:64,76,64,6
  [[ $output =~ timeseries\ size:64,76,64,12 ]]
  [ $status -eq 0 ]
}

@test "tempcorr_minvox" {
  # does not check there's no error
  run ROI_TempCorr.R -ts $shortrestfile -min_vox 3 -rois $roi
  [[ $output =~ timeseries\ size:64,76,64,6 ]]
  [ $status -eq 0 ]
}

@test "tempcorr_minvox_fail" {
  # fail when too many
  run ROI_TempCorr.R -ts $shortrestfile -min_vox 10000 -rois $roi
  [[ $output =~ "fewer than 10000 voxels" ]]
}
@test "single_voxel" {
  # fail when too many
  3dcalc -f $roi -expr '2*iszero(i-32)*amongst(j,32,33)*iszero(k-32)' -overwrite -prefix single_vox_roi.nii.gz
  3dcalc -f $shortrestfile -expr 'f*iszero(iszero(i-32)*iszero(j-32)*iszero(k-32))' -overwrite -prefix hole.nii.gz

  run ROI_TempCorr.R -ts hole.nii.gz -min_vox 1 -rois single_vox_roi.nii.gz
  [[ $output =~ n=6x1 ]]
  [[ $status -eq 0 ]]
}
