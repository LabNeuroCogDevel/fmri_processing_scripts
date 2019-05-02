#!/bin/bash

set -e
set -x

if [ $# -eq 0 ]; then
    echo "No command line parameters provided. Expect -target, -maskfilename, and -refmask."
    exit 1
fi

outputFile="countMaskMatch.txt"
masklist=()
pathmatch=
#process command line parameters
while [ _$1 != _ ] ; do
    if [ $1 = -target ]; then
	basedir="${2}"
	shift 2
    elif [ $1 = -maskfilename ]; then
	maskfilename="${2}"
	shift 2
    elif [ $1 = -pathmatch ]; then
	pathmatch="${2}"
	shift 2
    elif [ $1 = -masklist ]; then
	shift 1
	while [ "${1:0:1}" != "-" ]; do
	    masklist+=("$1")
	    shift 1    
	done
    elif [ $1 = -refmask ]; then
	refMask="${2}"
	shift 2
    elif [ $1 = -output ]; then
	outputFile="${2}"
	shift 2
    else
	#printHelp
	echo -e "----------------\n\n"
	echo "Unrecognized command line parameter: ${1}"
	exit 1
    fi
done

if [[ ! -f "${refMask}" ]] && [[ ! -h "${refMask}" ]]; then
    echo "Cannot locate reference mask: ${refMask}"
    exit 1
fi

#require that the path contains a string
[ -n "${pathmatch}" ] && pathmatch=" -ipath *${pathmatch}*"
echo "pathmatch: $pathmatch"
if [ -z "${masklist}" ]; then
    subjMasks=$( find "$basedir" -iname "${maskfilename}" ${pathmatch} ) || echo "Find returned non-zero exit status: $?"
elif [ "${#masklist[@]}" -eq 1 ]; then
    echo "assuming a list was provided: ${masklist[0]}"
    subjMasks=$(<${masklist[0]})
else
    subjMasks="${masklist[@]}"
fi

numMask=$( 3dBrickStat -count -non-zero "${refMask}" )
numMask=$( echo ${numMask/ /} )
echo "Number of voxels in reference mask: ${numMask}"

echo -e "NumMiss\tSubject\tRun" > "${outputFile}"
for mask in ${subjMasks}; do
    #custom to bars at the moment
    #subjId=$( echo "${mask}" | perl -pe 's/^.*\/(\d+)\/.*$/\1/' )
    #runNum=$( echo "${mask}" | perl -pe 's/^.*\/bars_run(\d+)\/.*$/\1/' )
    
    #subtract the subject mask from the reference and only retain positive non-zero values (indicative of where subject is missing voxels relative to mask)
    fslmaths "${refMask}" -sub "${mask}" -thr 0 subtract_mask -odt char
    numMiss=$( 3dBrickStat -count -non-zero "subtract_mask.nii.gz" )
    numMiss=$( echo ${numMiss/ /} )
    #echo "Subject: ${subjId}, run: ${runNum} missing ${numMiss} relative to reference mask."
    #echo -e "${numMiss}\t${subjId}\t${runNum}" >> "unsorted_${outputFile}"
    echo -e "${numMiss}\t${mask}" >> "unsorted_${outputFile}"
done

sort -rn "unsorted_${outputFile}" >> "${outputFile}"

rm "unsorted_${outputFile}"
rm -f subtract_mask.nii.gz
