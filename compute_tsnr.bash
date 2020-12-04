#!/bin/bash

set -ex
cmrrdirs=$( ls -d *cmrr_mbep2d* | grep -v sbref )
#env

module load fsl/5.0.8 >/dev/null 2>&1
module load afni/16.0.00 >/dev/null 2>&1

[ ! -d tsnr_maps ] && mkdir tsnr_maps

for d in ${cmrrdirs}; do
    cd ${d}
    #create a cubic detrended version of the processed data to compute the Tstd
    3dDetrend -overwrite -prefix ktm_functional_detrend.nii.gz -polort 3 ktm_functional.nii.gz

    #detrended version (for temporal sd)
    applywarp --ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_2mm --in=ktm_functional_detrend --out=wktm_functional_detrend --interp=spline \
	      --premat=func_to_struct.mat --warp=../../mprage/mprage_warpcoef --paddingsize=0 --mask=wktm_functional_98_2_mask_dil1x

    #non-detrended version (for temporal mean) 
    applywarp --ref=$HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_brain_2mm --in=ktm_functional --out=wktm_functional --interp=spline \
	      --premat=func_to_struct.mat --warp=../../mprage/mprage_warpcoef --paddingsize=0 --mask=wktm_functional_98_2_mask_dil1x

    #also look pre- and post-despiking
    3dDetrend -overwrite -prefix wdktm_functional_detrend.nii.gz -polort 3 wdktm_functional.nii.gz

    #before despike tsnr
    fslmaths wktm_functional -Tmean ${d}_tmean_predespike
    fslmaths wktm_functional_detrend -Tstd ${d}_tstd_predespike

    fslmaths ${d}_tmean_predespike -div ${d}_tstd_predespike ${d}_tsnr_predespike
    mv ${d}_tsnr_predespike.nii.gz ${d}_tmean_predespike.nii.gz ${d}_tstd_predespike.nii.gz ../tsnr_maps

    #after despike tsnr
    fslmaths wdktm_functional -Tmean ${d}_tmean_postdespike
    fslmaths wdktm_functional_detrend -Tstd ${d}_tstd_postdespike

    fslmaths ${d}_tmean_postdespike -div ${d}_tstd_postdespike ${d}_tsnr_postdespike
    mv ${d}_tsnr_postdespike.nii.gz ${d}_tmean_postdespike.nii.gz ${d}_tstd_postdespike.nii.gz ../tsnr_maps

    cd ..
done

cd tsnr_maps
tsnrmaps=$( ls -d *cmrr*tsnr* )

fslmaths $HOME/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_gm_tal_nlin_asym_09c_2mm -thr 0.2 -bin gm_p0.2_mask

echo "" > tsnr_mean_gm0.2
for f in $tsnrmaps; do
    echo $f >> tsnr_mean_gm0.2
    fslstats $f -k gm_p0.2_mask -M >> tsnr_mean_gm0.2
    echo "" >> tsnr_mean_gm0.2
done
