#!/usr/bin/env bats

##########################
# test motion regression #
##########################

# given file and column number
# return that col as a row
col(){
  sed 's/^ //' $1 |
  cut -f$2 -d' '|
  tr '\n' ' '|
  sed 's/ $//'
}
colcnt() {
  awk '{print NF}' $1|sort |uniq
}

# create a motion.par file
setup() {
 source ../preproc_functions/helper_functions
 source ../preproc_functions/nuisance_regression
 mkdir batsmotiontempdir
 cd batsmotiontempdir
 cat > motion.par <<EOF
5 2 3 4 5 6
10 20 30 40 50 60
30 25 20 15 10 5
5 2 3 4 5 6
EOF

  nuisance_file=nf



  # columns as they'd be calculated
    firstcol="5 10 30 5"

      firstd="0 5 20 -25" 

   firstquad="25 100 900 25" 
  firstquadd="0 25 400 625" 

        dry="0 18 5 -23"
}

# remove cor text file a the end
teardown() {
 cd ..
 rm -r batsmotiontempdir
 return 0
}


@test "d6motion" {
  no_warp=1
  nuisance_regressors=d6motion
  compute_nuisance_regressors 
  [ "$(col .motion_deriv 1)" == "$firstd" ]
  [ "$(col nf 1)" == "$firstd" ]
}

@test "q6motion" {
  no_warp=1
  nuisance_regressors=q6motion
  compute_nuisance_regressors 
  [ "$(col .motion_quad 1)" == "$firstquad" ]
  [ "$(col nf 1)" == "$firstquad" ]
  [ $(colcnt nf) -eq 6 ]
}

@test "qd6motion" {
  no_warp=1
  nuisance_regressors=qd6motion
  compute_nuisance_regressors 
  [ "$(col .motion_deriv_quad 1)" == "$firstquadd" ]
  [ "$(col nf 1)" == "$firstquadd" ]
  [ $(colcnt nf) -eq 6 ]
}
# dry sorted before qd6motion, should be first in nuisance
@test "qd6motion,dry" {
  no_warp=1
  nuisance_regressors=qd6motion,dry
  compute_nuisance_regressors 

  # 7 regressors in final output
  [ $(colcnt nf) -eq 7 ]
  # first line of motion deriv quad
  [ "$(col .motion_deriv_quad 1)" == "$firstquadd" ]
  # is not first line of final output
  [ "$(col nf 1)" == "$dry" ]
}

