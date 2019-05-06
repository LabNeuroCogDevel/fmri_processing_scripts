#!/usr/bin/env bats

###################
# test lock funcs #
###################

# go into a special temp dir
setup() {
 cd $BATS_TEST_DIRNAME
 source ../preproc_functions/helper_functions
 source ../preproc_functions/waitforlock
}

#teardown() {
#}

@test "create, test, and remove lockfile" {
 makelockfile testlock
 [ -r testlock ]
 fileislocked testlock 
 rmlockfile testlock
}

@test "hour old lock is not a lock" {
 date -d "1 hour ago" +%s > testlock
 sleep 1
 ! fileislocked testlock
 rmlockfile testlock
}

@test "no file, no problem" {
  rmlockfile testlock
  ! fileislocked testlock

  tic=$(date +%s)
  waitforlock testlock
  toc=$(date +%s)
  [ $((( $toc - $tic ))) -le 1 ]
}

@test "wait for lock to clear (hang for 4s)" {
  makelockfile testlock

  tic=$(date +%s)
  (sleep 4; rm testlock) &
  waitforlock testlock
  toc=$(date +%s)

  [ $((( $toc - $tic ))) -ge 3 ]
}
