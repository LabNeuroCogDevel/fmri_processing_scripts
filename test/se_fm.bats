#!/usr/bin/env bats

###################
# test lock funcs #
###################

# go into a special temp dir
setup() {
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_fieldmap
 BATS_TMPDIR=$(mktemp -d /tmp/bats_XXXX)
}

teardown() {
 [ $BATS_TMPDIR  != "/tmp" -a -d $BATS_TMPDIR ] && rm -r $BATS_TMPDIR
 return 0
}


@test "convert_or_use_nii()" {
  cp -r $BATS_TEST_DIRNAME/dcms $BATS_TMPDIR/
  convert_or_use_nii testimg "$BATS_TMPDIR/dcms/"
  [ -r testimg.nii.gz ] 
}
