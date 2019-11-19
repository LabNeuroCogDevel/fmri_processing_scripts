#!/usr/bin/env bash

# create TMPD and go there
setup_TMPD() {
  # add all the tools we'd test to the path
  export PATH="$(readlink -f $BATS_TEST_DIRNAME/..):$PATH"
  # make directory
  TMPD=$(mktemp -d "$BATS_TMPDIR/XXXX")
  cd $TMPD
  pwd >&2
}

# remove TMPD unless SAVETEST is set
# reset SAVETEST
teardown_TMPD() {
  cd $BATS_TEST_DIRNAME
  [ -n "$TMPD" -a -d $TMPD -a -z "$SAVETEST" ] && rm -r $TMPD
  SAVETEST=""
  return 0
} 

# get the number of columns
# if more than one column count, counts pasted together
# if 16 and 17, returns 1617
ncol(){ awk '{print NF}' $@ |sort -u|tr -d '\n';}

# test file's last row and column like "192 16"
last_rowcol() { [[ "$(awk 'END{ print NR,NF}' $1)" == "$2" ]]; }

checkrange(){
 paste <( tr ' ' '\n' < $1 ) <( tr ' ' '\n' < $2 ) | 
 perl -salne '$a+=abs($F[0]-$F[1]); END{$m=$a/$.; $s=$m>$mn && $m<$mx; print("$mn < $m < $mx: ", !$s); exit(!$s)}' -- -mn=$3 -mx=$4
}
