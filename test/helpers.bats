#!/usr/bin/env bats

###################
# test lock funcs #
###################

# source the functions we want to test
setup() {
 source ../preproc_functions/helper_functions
}

#teardown() {
#}

@test "imtestln" {
  # setup
  d=$(mktemp -d $BATS_TMPDIR/imtestlnXXXX)
  cd $d
  mkdir -p a b/c
  3dUndump -dimen 6 6 6 -srad 1 -ijk  -prefix tmp.nii.gz -overwrite  <(echo -e "1 1 2 1\n2 2 2 2\n3 1 1 3") 
  ln -s tmp.nii.gz tmp_ln.nii.gz
  cd $d/b/c
  ln -s ../../tmp.nii.gz ./tmp_rel.nii.gz
  ln -s ../../dne.nii.gz ./tmp_bad.nii.gz
  cd $d
  # . 
  # |- tmp.nii.gz           (f)
  # |- tmp_ln.nii.gz        (l)
  # |- b/c
  # |    |- tmp_rel.nii.gz  (l)
  # |    |- tmp_bad.nii.gz  (badlink)

  run imtestln doesnotexist.nii.gz
  [ $status -ne 0 ]
  run imtestln doesnotexist
  [ $status -ne 0 ]
  run imtestln does/not/exist
  [ $status -ne 0 ]
  run imtestln does/not/exist.nii.gz
  [ $status -ne 0 ]

  run imtestln b/c/tmp_bad.nii.gz
  [ $status -ne 0 ]

  run imtestln tmp
  [ $status -eq 0 ]
  run imtestln tmp_ln.nii.gz
  [ $status -eq 0 ]
  run imtestln b/c/tmp_rel.nii.gz
  [ $status -eq 0 ]
  run imtestln tmp_ln
  [ $status -eq 0 ]
  run imtestln b/c/tmp_rel
  [ $status -eq 0 ]

  cd a

  # HERE IS THE ISSUE
  # imtest things that this file doesnt exist
  # but it does!
  [ $(imtest ../b/c/tmp_rel.nii.gz) -eq 0 ]

  run imtestln ../b/c/tmp_rel.nii.gz
  [ $status -eq 0 ]
  run imtestln ../b/c/tmp_rel
  [ $status -eq 0 ]


  # cleanup
  cd
  rm -r $d

}

# from helper_funcs: randomsleep imtestln a_is_b isglob cnt
@test "abspath" {
 [ "$(pwd)/b" = "$(abspath "$(pwd)/b")" ]
 [ "$(pwd)/b" = "$(abspath "./b")" ]
 [ "$(pwd)/b" = "$(abspath "b")" ]
 # //b is okay .. and what we get :(
 [[ "$(abspath "/b")" =~ /*/b ]]
}

@test "a_is_b" {
 cd $BATS_TMPDIR
 echo "1" > a
 echo "1" > b
 echo "c" > c
 a_is_b a a
 a_is_b b a
 a_is_b a b
 ! a_is_b a c
 ! a_is_b c a

 rm a b c
}

@test "isglob" {
 isglob "*"
 isglob "MR*"
 isglob "*dcm"
 ! isglob "path/to/nothing"
 ! isglob "$(pwd)"
 isglob "$(pwd)/*"
 isglob "$(pwd)/MR*"
 isglob "$(pwd)/*dcm"
}

@test "cnt" {
 cd $BATS_TMPDIR
 echo "1" > abc1
 echo "1" > abc2
 echo "c" > abc3
 [ $(cnt "abc[123]") -eq 3 ]
}

@test "rel" {
 cd $BATS_TMPDIR
 logFile="testlogfile"
 rel "echo \"hello world\" > foobar"
 [ -r foobar ]
 [ "$(cat foobar)" = "hello world" ]
 [ "$(tail -n1 $logFile)" == 'echo "hello world" > foobar' ]
 rm foobar

 out=$(rel "echo a > foobar" c)
 [ ! -r foobar ]
 [ "$(tail -n1 $logFile)" == "## echo a > foobar" ]
}

@test "rel timeit" {
 cd $BATS_TMPDIR
 logFile="testlogfile"
 rel "sleep 1" t >/dev/null
 egrep -q "took [12] s" $logFile
}


# @test "randomsleep" {
#  tic=$(date +%s)
#  randomsleep
#  toc=$(date +%s)
#  echo $tic >&2
#  echo $toc >&2
#  time=$(echo " $toc - $tic"|bc)
#  echo $time >&2
#  [ $time -le 2 -a $time -gt 0 ]
# }
