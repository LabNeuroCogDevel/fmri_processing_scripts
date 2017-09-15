#!/usr/bin/env bats

setup(){
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/onestep_warp_parts
}


@test "preMC:mc_target" {
  warp_target="mc_target"

  # easiest case
  mc_first=1
  no_st=1
  output=$(what_to_warp )
  [ $output =  "preMC" ]

  # it doesn't matter what despike or 4D is
  # as long as one or both of nost/mcfirst is true
  echo -e "1 0\n0 1\n1 1" | while read no_st mc_first; do
     for despike in 1 0; do
       for sliceMotion4D in 1 0; do
         [ "$(what_to_warp )" = "preMC" ]
       done
     done
  done

  no_st=0 
  mc_first=0
  [ "$(what_to_warp )" != "preMC" ]
}

@test "preMC:standard" {
  warp_target="standard"

  # easiest case
  mc_first=1
  no_st=1
  sliceMotion4D=0
  output=$(what_to_warp )
  [ $output =  "preMC" ]

  # it doesn't matter what despike and mc_first are
  # as long as no_st and/or st_first is true
  # and we didn't do sliceMotion4d
  echo -e "1 0\n0 1\n1 1" | while read no_st st_first; do
     for despike in 1 0; do
       for mc_first in 1 0; do
         output="$(what_to_warp )"
         ! [ "$output" = "preMC" ] && echo "$output: d$despike 4d$sliceMotion4D st$no_st mc$mc_first stf$st_first target:$warp_target" >&2 && return 1 || continue
       done
     done
  done
}


@test "despike" {
  despike=1

  # mc_target
  warp_target="mc_target"
  no_st=0; mc_first=0;
  [ "$(what_to_warp)" = "postDespike" ]

  warp_target="standard"
  no_st=0; st_first=0; sliceMotion4D=1
  [ $(what_to_warp ) =  "postDespike" ]

  no_st=0; st_first=0; sliceMotion4D=0
  output=$(what_to_warp )
  [ $output =  "postDespike" ]

}
@test "nodespike" {
  despike=0

  # mc_target
  warp_target="mc_target"
  no_st=0; mc_first=0;
  [ "$(what_to_warp)" = "postSS" ]

  warp_target="standard"
  no_st=0; st_first=0; sliceMotion4D=1
  [ $(what_to_warp ) =  "postSS" ]

  no_st=0; st_first=0; sliceMotion4D=0
  output=$(what_to_warp )
  [ $output =  "postSS" ]

}
