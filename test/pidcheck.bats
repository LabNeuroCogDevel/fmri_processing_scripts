#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/helper_functions
 source ../preproc_functions/pidcheck
 cd /tmp/
}

teardown() {
 [ ! -r .preproc_pid ] && rm .preproc_pid
 return 0
}

@test "create and remove" {
  writepid
  [ -r $PREPROCPID ]
  read p s h < "$PREPROCPID"
  [ "$h" == "$(uname -n)" ]

  rmpidfile
  [ ! -r $PREPROCPID ]
}

@test "continue if no file" {
  pidcheck
}
@test "stop if valid pidfile" {
  writepid
  ! pidcheck
  rmpidfile
}

@test "remove and continue no matching pid" {
  echo "0000 $(date +%s) $(uname -n)" > $PREPROCPID
  pidcheck
}

@test "stop if different host" {
  echo "0000 $(date +%s) nothiscomputer" > $PREPROCPID
  ! pidcheck
}
@test "continue if different host but too old" {
  echo "0000 $(date -d '2 days ago' +%s) nothiscomputer" > $PREPROCPID
  pidcheck
}
