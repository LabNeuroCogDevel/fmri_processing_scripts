#!/usr/bin/env bats


shortrestfile="inputs/functest.nii.gz"  # 6 time points from a fully preproc'ed WM run1
mask="inputs/gm_50mask.nii.gz"
roi="inputs/wm_spheres.nii.gz"

# remove cor text file a the end
teardown() {
 [ -r corr_rois.txt ] && rm corr_rois.txt
 return 0
}


@test "run with mask" {
  ../ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi
  results=$(awk 'END{print NR,NF}' corr_rois.txt)
  [ "$results" == "33 33" ]
}

@test "run with 1 job" {
  ../ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1
  results=$(awk 'END{print NR,NF}' corr_rois.txt)
  [ "$results" == "33 33" ]
}

## Partial correlation
@test "semi cor" {
  ../ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 1 -corr_type semi
  results=$(awk 'END{print NR,NF}' corr_rois.txt)
  [ "$results" == "33 33" ]
}
@test "semi cor -- reset 10 jobs to 1" {
  ../ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 10 -corr_type semi
  results=$(awk 'END{print NR,NF}' corr_rois.txt)
  [ "$results" == "33 33" ]
}

@test "semi cor fail with bad type" {
  ! ../ROI_TempCorr.R -ts $shortrestfile -brainmask  $mask -rois $roi -njobs 10 -corr_type semi -corr_method pairwiseGK 
}


