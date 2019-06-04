#!/usr/bin/env bats

####################
# test arg parsing #
####################

setup() {
 source $BATS_TEST_DIRNAME/../preproc_functions/parse_args
}

# check depends runs
@test "check_dependencies" {
 # just one
 run check_dep_list echo
 [ $status -eq 0 ]

 # many
 run check_dep_list echo ls cd
 [ $status -eq 0 ]

 run check_dep_list this_does_not_exist
 [ $status -eq 1 ]

 run check_dep_list this_does_not_exist this_also_doesnt_exist
 [ $status -eq 2 ]

 # python
 run check_dep_list python:sys python:os
 [ $status -eq 0 ]

 run check_dep_list python:module_does_not_exist
 [ $status -eq 1 ]

 #perl
 run check_dep_list perl:Data::Dumper
 [ $status -eq 0 ]

 run check_dep_list perl:DNE::module_DNE
 [ $status -eq 1 ]
}
