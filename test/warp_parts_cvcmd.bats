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
 prepare_fieldmap_bbr() {
    if [[ $bbrCapable -eq 1 && $funcStructFlirtDOF = "bbr" && -n "$fm_cfg" ]]; then
	createBBRFmapWarp=1 #generate func -> struct warp that includes FM unwarping (via BBR -fieldmap)
    else
	createBBRFmapWarp=0
    fi
 }
 echo_params(){ echo "out '$output'= want '$1'; fm:'$use_fm' mc:'$mc_first' 4d:'$sliceMotion4D' '$warp_target'" >&2 ; }
 extractfslinputs(){ tr '[ \t]' '\n'|sed -n s/--//p |grep -v out; } # | tr '\n' ' '; }

 # recursively set flags as both 1 and 0
 # at end of recusion, run command using all flags
 cvcmflags(){
   local flag=$1; shift
   printf -v ${flag} 0
   while [ ${!flag} -le 1 ]; do
      if [ -n "$1" ]; then
        cvcmflags $@
      else
        local all=${warp_target:0:1}$use_fm$sliceMotion4D$no_st$st_first$mc_first$no_warp$despike
        if [[ 
          $all = s000000[01]    ||
          $all = s000001[01]    ||
          $all = s10000[01][01] ||
          $all = m0000000       ||
          $all = m0000001       ||
          $all = m1000000       ||
          $all = m1000001       ||
          $all = m0000010       ||
          $all = m1000011       ||
          $all = m0000011       ||
          $all = m0000010       ||
          $all = m1000010       ||
          $all = m[01]01[01]00[10] ||
          $all = m100100[10]    ||
          $all = m001001[10]    ||
          $all = m000010[10]    ||
          $all = m00010[01][10] ||
          $all = m001[01]01[10] ||
          $all = m100101[01] 
        ]] ; then 
          echo bad
        else
          echo $all >&2
          fmap_unwarp_field=$(find_fm_warp_field)
          warp_convert_command
        fi
      fi
      printf -v ${flag} $[ ${!flag} + 1] 
   done
 }

}


@test "cvcmd: all var combos" {

  ref="ref"
  warpCoef="warpCoef"
  funcdir=.

  for warp_target in standard mc_target;do
   cvcmflags no_warp use_fm sliceMotion4D no_st mc_first st_first despike
  done

}
# parse args does not allow 4d_slice_motion and mc_first
@test "cvcmd: parse_args: fm" {
  # setup
  parse_args -fm_phase "dummy" -log "" -4d_slice_motion
  warp_to_template_warp_target
  fmap_unwarp_field=$(find_fm_warp_field)
  ref="ref"
  warpCoef="warpCoef"
  funcdir=.

  warp_convert_command
  eval $(echo $cvcmd | extractfslinputs )
  # only  have what we'll check
  [ $(echo $cvcmd | extractfslinputs |wc -l) -eq 4 ]
  # check all is what we expect
  [ $ref    = "ref" ] 
  [ $warp1  = "unwarp/EF_UD_warp" ] 
  [ $midmat = "./transforms/func_to_struct.mat" ] 
  [ $warp2  = "warpCoef" ] 

  
}

@test "cvcmd: parse_args: fm and bbr" {
  # setup
  parse_args -fm_phase "dummy" -log "" -4d_slice_motion -fm_cfg pet -func_struc_dof bbr
  warp_to_template_warp_target
  prepare_fieldmap_bbr
  fmap_unwarp_field=$(find_fm_warp_field)
  ref="ref"
  warpCoef="warpCoef"
  funcdir=.

  warp_convert_command
  eval $(echo $cvcmd | extractfslinputs )
  # only  have what we'll check
  [ $(echo $cvcmd | extractfslinputs |wc -l) -eq 4 ]
  # check all is what we expect
  [ $ref    = "ref" ] 
  [ $warp1  = "unwarp/EF_UD_warp_bbr" ] 
  [ $midmat = "./transforms/func_to_struct.mat" ] 
  [ $warp2  = "warpCoef" ] 
  
}

@test "cvcmd: with nofm" {
  # setup
  parse_args -log "" -func_struc_dof bbr
  warp_to_template_warp_target
  prepare_fieldmap_bbr
  fmap_unwarp_field=$(find_fm_warp_field)
  ref="ref"
  warpCoef="warpCoef"
  funcdir=.

  warp_convert_command
  eval $(echo $cvcmd | extractfslinputs )
  # only  have what we'll check
  [ $(echo $cvcmd | extractfslinputs |wc -l) -eq 4 ]
  # check all is what we expect
  [ $ref    = "ref" ] 
  [ $warp1  = "unwarp/EF_UD_warp_bbr" ] 
  [ $midmat = "./transforms/func_to_struct.mat" ] 
  [ $warp2  = "warpCoef" ] 
  
}
