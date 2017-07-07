#!/usr/bin/env bats

###################
# test lock funcs #
###################

# go into a special temp dir
setup() {
 source ../preproc_functions/helper_functions
 source ../preproc_functions/waitforlock
}

# exit and remove temp dir
#teardown() {
#}

# check default is to not trunc
@test "create test and remove lockfile" {
 makelockfile testlock
 [ -r testlock ]
 fileislocked testlock 
 rmlockfile testlock
}

# check setting trunc
@test "hour old lock is not a lock" {
 date -d "1 hour ago" +%s > testlock
 sleep 1
 ! fileislocked testlock
 rmlockfile testlock
}

@test "wait for lock to clear (hang for 3s)" {
  makelockfile testlock

  tic=$(date +%s)
  (sleep 4; rm testlock)
  waitforlock testlock
  toc=$(date +%s)

  [ $((( $toc - $tic ))) -ge 3 ]
}
