#!/usr/bin/env bats

#########################
# test wavlet despiking #
#########################


# go into a special temp dir
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/helper_functions
 source ../preproc_functions/template_funcs
 reference=MNI_2mm
 OLD=/opt/ni_tools/standard_templates_old
 NEW=/opt/ni_tools/standard_templates
 mfile09c="$BATS_TEST_DIRNAME/exampledata/mprage09c18/mprage_bet.nii.gz"
 mfilebad="exampledata/mprage_old09c/mprage_bet.nii.gz"
 [ ! -d $OLD/ ] && skip
 [ ! -d $NEW/ ] && skip
 [ ! -r $mfile09c ] && skip "missing mprage 09c example : $mfile09c"
 [ ! -r $mfilebad ] && skip "missing mprage bad example: $mfilebad"
 return 0
}

@test "new is fine" {
 stddir=$NEW
 run old_template_check
 echo $stderr
 [[ $status -eq 0 ]]
}

@test "die with old std" {
 stddir=$OLD
 run old_template_check
 [[ $status -eq 1 ]]
}

@test "switch to old" {
 stddir=$NEW
 USE_OLD_TEMPLATE="yes"
 old_template_check
 [[ $stddir == $OLD ]]
}

@test "die with bad mprage" {
 source ../preproc_functions/parse_args
 parse_args -mprage_bet $mfilebad -warpcoef $mfilebad -4d $mfilebad -log ""
 run old_template_check
 [[ $status == 1 ]]
}

@test "bad mprage okay with use old" {
 source ../preproc_functions/parse_args
 parse_args -mprage_bet $mfilebad -warpcoef $mfilebad -4d $mfilebad -use_old_mni -log ""
 old_template_check
 [[ $USE_OLD_TEMPLATE == "yes" ]]
 [[ $stddir == $OLD ]]
}

@test "no problem with new mprage" {
 source $BATS_TEST_DIRNAME/../preproc_functions/parse_args
 parse_args -mprage_bet $mfile09c -warpcoef $mfile09c -4d $mfile09c -log ""
 run old_template_check
 [[ $status -eq 0 ]]
 #[[ -z $USE_OLD_TEMPLATE  ]]
 #[[ $stddir == $NEW ]]
}

@test "new mprage trying to use old" {
 source $BATS_TEST_DIRNAME/../preproc_functions/parse_args
 parse_args -mprage_bet $mfile09c -warpcoef $mfile09c -4d $mfile09c -log "" -use_old_mni
 run old_template_check 
 [[ $status == 1 ]]
}
