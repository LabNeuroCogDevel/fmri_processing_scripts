#!/usr/bin/env bats

setup() {
 INPUTDIR="$BATS_TEST_DIRNAME/exampledata/ncanda_fm/"
 [ ! -d $INPUTDIR ] && skip
 source $BATS_TEST_DIRNAME/../preproc_functions/prepare_fieldmap
}

@test "fugue warpdir" {
 run warpdir_for_fugue x 
 [ "$output" == "x-" ]

 run warpdir_for_fugue x- 
 [ "$output" == "x" ]
 
 run warpdir_for_fugue y- 
 [ "$output" == "y-" ]

 run warpdir_for_fugue y 
 [ "$output" == "y" ]
}

