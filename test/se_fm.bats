#!/usr/bin/env bats

###################
# test lock funcs #
###################

# go into a special temp dir
setup() {
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_fieldmap
 TMPDIR=$(mktemp -d $BATS_TMPDIR/bats_XXXX)
 cd "$TMPDIR"
}

teardown() {
 cd -
 rm -r "$TMPDIR"
 return 0
}


@test "spin echo fiedlmap" {
   # have no examples (20190502)
   skip
}
