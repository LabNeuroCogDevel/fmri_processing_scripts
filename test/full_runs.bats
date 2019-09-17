
setup() {
  MYTMPDIR=$BATS_TMPDIR/fullrun
  mkdir -p $MYTMPDIR
  EXDIR=$BATS_TEST_DIRNAME/exampledata
  cd $MYTMPDIR
}
teardown() {
 cd ..
 rm -r $TMPDIR
 return 0
}

@test "no_{mc,st,warp}: autocorr + nuisance" {
  # make some fake data with enough timesteps
  3dWarp -prefix func.nii.gz -overwrite -deoblique $EXDIR/short_func.nii.gz
  3dTcat -prefix "func.nii.gz" -overwrite func.nii.{gz,gz,gz,gz,gz}
  $BATS_TEST_DIRNAME/../preprocessFunctional -4d func.nii.gz -bandpass_filter 0.009 .08 -nuisance_regression gs -rmautocorr  -no_mc -no_st -no_warp -tr 1 -mprage_bet $EXDIR/mprage09c18/mprage_bet.nii.gz
  ls >&2
  ls >&3
  [ -r Abrnsk_func_5.nii.gz ]
}
