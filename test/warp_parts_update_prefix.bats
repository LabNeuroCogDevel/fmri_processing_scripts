#!/usr/bin/env bats

setup(){
 source $BATS_TEST_DIRNAME/../preproc_functions/helper_functions
 source $BATS_TEST_DIRNAME/../preproc_functions/onestep_warp_parts
 source $BATS_TEST_DIRNAME/../preproc_functions/parse_args

 # mimc warp_to_template's logic to set warp target
 warp_to_template_warp_target() {
    warp_target=""
    if [ $no_warp -eq 1 ]; then 
       [[ $mc_first -eq 0 || $sliceMotion4D -eq 1 ]] && warp_target=mc_target 
    else 
       warp_target=standard
    fi

    return 0
 }
 echo_params(){ echo "out '$output'= want '$1'; fm:'$use_fm' mc:'$mc_first' 4d:'$sliceMotion4D' '$warp_target'" >&2 ; }

}


@test "update_prefix fails" {
  run update_prefix ""
  [ $status -eq 1 ]
}
@test "update_prefix no change" {
  run update_prefix "abc"
  [ "$output" = "abc" ]
}

@test "update_prefix most likey config" {
  warp_target=standard; use_fm=1; mc_first=0; answer=wu
  run update_prefix "_"
  [ $output = "wu_" ]
}
@test "update_prefix explict variable (all combos)" {
  cat >$BATS_TMPDIR/prefixlist <<EOF 
standard 1 1 w
standard 1 0 wu
standard 0 1 w
standard 0 0 w
mc_target 1 1 u
mc_target 1 0 u
mc_target 0 1
mc_target 0 0
EOF
 while IFS=' ' read warp_target use_fm mc_first answer; do
    export use_fm mc_first warp_target
    run update_prefix "_"
    [ $status -eq 0 ]
    echo_params ${answer}_
    [ "$output" = "${answer}_" ]
 done < $BATS_TMPDIR/prefixlist
}


@test "update_prefix u_: parse_args no_warp + fm_phase" {
  # mc_first and slicemotion4d are both 0
  parse_args -no_warp -fm_phase "dummy" -log ""
  warp_to_template_warp_target
  [ $(update_prefix "_") = 'u_' ]
}
@test "update_prefix u_: parse_args no_warp + fm_phase: mc_first only" {
  # mc_first without slicemotion means fildmap unwarping already happened?
  # BUT only for standard. this is mc
  parse_args -no_warp -mc_first -fm_phase "dummy" -log ""
  warp_to_template_warp_target
  run update_prefix "_"
  echo_params "u_"
  [ $output = 'u_' ]
}
@test "update_prefix u_: parse_args no_warp + fm_phase: 4d_slice_motion only" {
  # mc_first=0 and slicemotion4d=1 = "u_"
  parse_args -no_warp -4d_slice_motion -fm_phase "dummy" -log ""
  warp_to_template_warp_target
  [ $(update_prefix "_") = 'u_' ]
}

# parse_args does not allow mc_first and 4d_slice_motion
@test "update_prefix u_: parse_args no_warp + fm_phase: mc_first + 4d_slice_motion -- not allowed by parse_args" {
  skip 
  # mc_first and slicemotion4d are both 1
  echo "parseargs" >&2
  parse_args -no_warp -mc_first -4d_slice_motion  -fm_phase "dummy" -log ""
  echo "warpparm" >&2
  warp_to_template_warp_target
  echo_params "u_"
  [ $(update_prefix "_") = 'u_' ]
}



@test "update_prefix w_: parse args fm_phase: warp + no fm" {
  parse_args  -log ""
  warp_to_template_warp_target
  run update_prefix "_" 
  echo_params "w_"
  [ $output = 'w_' ]
}
@test "update_prefix wu_:parse args fm_phase: warp + fm" {
  parse_args  -fm_phase "dummy" -log ""
  warp_to_template_warp_target
  run update_prefix "_" 
  echo_params "wu_"
  [ $output = 'wu_' ]
}

@test "update_prefix w_: parse args fm_phase: warp + fm + mc_first" {
  parse_args -fm_phase "dummy" -log "" -mc_first
  warp_to_template_warp_target
  run update_prefix "_" 
  echo_params w_
  [ $output = 'w_' ]
}

# parse args does not allow 4d_slice_motion and mc_first
@test "update_prefix w_: parse args fm_phase: warp + fm + mc_first + slicemotion -- not allowed by parse_age" {
  skip
  parse_args -fm_phase "dummy" -log "" -mc_first -4d_slice_motion
  warp_to_template_warp_target
  run update_prefix "_" 
  echo_params w_
  [ $output = 'w_' ]
}
