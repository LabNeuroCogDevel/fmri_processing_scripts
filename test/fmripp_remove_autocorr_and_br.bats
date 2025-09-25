#!/usr/bin/env bats

###############################
# test remove_autocorr_and_br #
###############################


mknii() {
 name=$1; shift
 3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix $name -overwrite  <(echo -e $@)
}

# go into a special temp dir
setup() {
 THISTESTDIR=$(mktemp -d $BATS_TMPDIR/autocor-XXX)
 cd ${THISTESTDIR}
 MRI_STDDIR=$THISTESTDIR # to stop helper_functions from complaining about missing MNI
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/parse_args
 source $BATS_TEST_DIRNAME/../preproc_functions/nuisance_regression # regression_todo reg_todo_to_desc nuisance_regression

 # for where to save log file
 funcdir=$(pwd) 

 # create a test dataset
 mknii 1.nii.gz "3 3 3 1"
 mknii 2.nii.gz "3 3 4 1"
 mknii 3.nii.gz "3 2 3 1"
 mknii 4.nii.gz "3 3 3 1"
 # construct so we will remove up to the odd one out
 # 16 timepoints
 3dTcat -prefix "test.nii.gz" [1-4].nii.gz [1-4].nii.gz  [1-4].nii.gz [1-4].nii.gz  [1-4].nii.gz 1.nii.gz

 # COMPUTE_NUISANCE_REGRESSORS_GLOBALS=(nuisance_file nuisance_regressors no_warp postWarp postDespike postSS templateName mprageBet_base ext tr prefix)
 # compute_nuisance_regressors 
}

# remove tempdir and contents
teardown() {
 cd ..
 test -d "${THISTESTDIR}" && rm -r ${THISTESTDIR} || echo "WARNING: no tempdir $THISTESTDIR ?" >&2
 return 0
}




@test "autocorr settings" {

  parse_args -4d test.nii.gz -rmautocorr -bandpass_filter 0.009 .08
  [ "$rmautocorr" -eq 1 ]
  [ "$bpLow"  = "0.009" ]
  [ "$bpHigh" =  ".08" ]
}

# GLOBAL $tr, $nuisance_file, $bpLow, $bpHigh
@test "simple_run no regs" {
  # set bpLow, bpHigh and rmautocorr=1
  parse_args -4d test.nii.gz -rmautocorr -bandpass_filter 0.009 .08
  # setup for nuisance_regression
  # not done by parse_args
  prefix="_"
  ln -s test.nii.gz ${prefix}test${smoothing_suffix}.nii.gz
  tr=1
  subjMask="test"
  nuisance_regression  
  [ $nuisance_regression -eq 0 ]

  # check that the prefix was added
  [ $prefix = "Ab_" ]
  # and the file was created: Ab_test_5.nii.gz
  [ -r "${prefix}test${smoothing_suffix}.nii.gz" ]

}

@test "autocorr + nuisance" {
  # make some fake data with enough timesteps
  ntim=30
  briks=( $(perl -le "print map {(\$i++%4 +1).'.nii.gz ' } (1...$ntim)" ) )
  3dTcat -prefix "test.nii.gz" -overwrite ${briks[@]}
  perl -e "print join(qq/\n/,map {rand(10)/10} (1..$ntim) )" > motion.par


  parse_args -4d test.nii.gz -bandpass_filter 0.009 .08 -nuisance_regression rx  -rmautocorr  
  [ "$rmautocorr" -eq 1 ]
  [ $nuisance_regression -eq 1 ]


  # setup for nuisance_regression
  # not done by parse_args
  prefix="_"
  ln -s test.nii.gz ${prefix}test${smoothing_suffix}.nii.gz
  tr=1
  subjMask="test"

  ## run it
  nuisance_regression  
  
  # check that the prefix was added
  [ $prefix = "Abr_" ]
  # and the file was created
  [ -r "${prefix}test${smoothing_suffix}.nii.gz" ]

  # added the nuisance_regressor to the final file
  nrow_basis=$(awk '{print NF}' .basis.1D|sort|uniq) # n filed in 1dBport
  nrow_all=$(awk '{print NF}' .nuisance_regressors.3dREMLfit|sort|uniq)
  #echo "# basis: $nrow_basis all: $nrow_all" >&3
  [ $nrow_basis -ge 21 ]          # number of TRs
  [ $nrow_all -ge $nrow_basis ]

  #cp -r . ../batsautocorr_sav

}

# compute but not used
@test "autocorr + compute nuisance only" {

  parse_args -4d test.nii.gz -bandpass_filter 0.009 .08 -nuisance_compute rx  -rmautocorr
  [ "$rmautocorr" -eq 1 ]
  [ "$nuisance_compute" -eq 1 ]
  [ "$nuisance_regression" -eq 0 ]


  ntim=$(3dinfo -nt test.nii.gz)
  perl -e "print join(qq/\n/,map {rand(10)/10} (1..$ntim) )" > motion.par
  # setup for nuisance_regression
  # not done by parse_args
  prefix="_"
  ln -s test.nii.gz ${prefix}test${smoothing_suffix}.nii.gz
  tr=1
  subjMask="test"

  nuisance_regression  

  # check that the prefix was added
  [ $prefix = "Ab_" ]
  # and the file was created
  [ -r "${prefix}test${smoothing_suffix}.nii.gz" ]

  # did NOT add the nuisance_regressor to the final file
  nrow_basis=$(awk '{print NF}' .basis.1D|sort|uniq)
  nrow_all=$(awk '{print NF}' .nuisance_regressors.3dREMLfit|sort|uniq)
  #echo "nbasis: $nrow_basis; nall: $nrow_all" >&3
  [ $nrow_all -ge $nrow_basis ]
  [ $nrow_basis -ge 15 ] # actual value is 16, why?

  #cp -r . ../batsautocorr_sav

}

@test "regression todo: bp+reg" {
 parse_args -4d fake.nii.gz -4d test.nii.gz -rmautocorr -bandpass_filter 0.009 .08 -log "" -nuisance_regression 6motion,csf,wm,dcsf,dwm
 todo=$(regression_todo)
 echo "$todo" >&2
 [[ $todo = Abr ]]
 [[ $(reg_todo_to_desc $todo) == bandpass+regress ]]
}
@test "regression todo: bp+reg (custom)" {
 parse_args -4d fake.nii.gz -custom_regression_prefix R  -4d test.nii.gz -rmautocorr -bandpass_filter 0.009 .08 -log ""  -nuisance_regression 6motion
 todo=$(regression_todo)
 echo "$todo" >&2
 [[ $todo = AbR ]]
 [[ $(reg_todo_to_desc $todo) == bandpass+regress ]]
}

@test "regression todo: bp" {
 parse_args -4d fake.nii.gz -4d test.nii.gz -bandpass_filter 0.009 .08 -log ""
 todo=$(regression_todo)
 echo "$todo" >&2
 [[ $todo = b ]]
 [[ $(reg_todo_to_desc $todo) == bandpass ]]
}

@test "regression todo: none" {
 parse_args -4d fake.nii.gz -4d test.nii.gz -log ""
 todo=$(regression_todo)
 echo "$todo" >&2
 [[ $todo = "" ]]
 [[ $(reg_todo_to_desc $todo) == none ]]
}
