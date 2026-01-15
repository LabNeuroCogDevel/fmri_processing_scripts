# MRI Preprocessing

[![DOI 10.5281/zenodo.8320244](https://zenodo.org/badge/5274327.svg)](https://doi.org/10.5281/zenodo.8320244)


## Tools

  * `preprocessMprage`
  * `preprocessFunctional`
    * `sliceMotion4d`
  * `ROI_TempCorr.R`


## Output scheme

[`preprocessFunctional`](preprocessFunctional#L=193) prepends each processing step as a prefix to each input, creating files like `brnaswutm_func.nii.gz`. In reverse order (order of name), the posible steps are:


|prefix | desc|
|---|-----|
|`A` | Auto Correlation removal (optional) |
|`b` | Bandpass filtering (optional, simultaneous with regression, for rest) |
|`g` | Global signal regression (optional, label optional, part of *r*) |
|`r` | Nuisance *r*egression (optional) |
|`n` | Intensity *n*ormalization |
|`f` | High-pass *f*iltering (optional, simultaneous with regression, for task) |
|`a` | ICA-AROMA (optional, requires warp) |
|`s` | Smoothing |
|`w` | Co-registration and *w*arping to standard space (spatial normalization, optional) |
|`u` | Field map unwarping (optional; Susceptibility Distortion Correction) |
|`d` | Intensity/wavelet *d*espiking (optional) |
|`k` | S*k*ull stripping and intensity thresholding |
|`mt` | 4D slice-time motion correction ([sliceMotion4d](sliceMotion4d))|
|`m` | *M*otion correction |
|`t` | Slice *t*iming correction |
|`p` | Physio/retroicor (optional) |
|`0` | truncate (optional, if scanner output includes disacq)|
|`_` | fslorient |

## Depends
see [bibtex](./preproc.bib) or plain text [citations](./citations.txt) and `preprocessFunctional -check_dependencies`

 * [ROBEX](https://sites.google.com/site/jeiglesias/ROBEX)
 * [ANTs](http://stnava.github.io/ANTs/)
 * [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
 * [ICA-AROMA](https://github.com/maartenmennes/ICA-AROMA)
   * v4 `aroma`: https://github.com/rtrhd/ICA-AROMA
   * orig repackages as `ica_aroma`: https://github.com/WillForan/ICA-AROMA/tree/maartenmennes-setup.py
 * [AFNI](https://afni.nimh.nih.gov/)
 * [MNI2009c](http://www.bic.mni.mcgill.ca/ServicesAtlases/ICBM152NLin2009)
 * [Brain Wavelet ToolboX](http://www.brainwavelet.org/downloads/brainwavelet-toolbox/)
 * [NiPy(4dslicewarp)](https://nipype.readthedocs.io/en/0.12.0/about.html)

## Testing

Limited testing using [bats](https://github.com/bats-core/bats-core) in `test/`.
see `make test` ([Makefile](./Makefile))

## See also
 * [fmriprep](https://fmriprep.readthedocs.io/en/stable/index.html), [clpipe](https://github.com/cohenlabUNC/clpipe), [xcp-d](https://github.com/PennLINC/xcp_d#when-you-should-not-use-xcp-d)
 * [afni\_proc](https://afni.nimh.nih.gov/pub/dist/doc/program_help/afni_proc.py.html)

## Usage Notes
### ROI Temp Corr
Running `ROI_TempCorr.R` is internally parallelized (default `njobs=4`). If you are also forking in e.g. a bash for loop like `ROI_TempCorr.R ... &` (and maybe paired with [lncdtool](https://github.com/lncd/lncdtools)'s [`waitforjobs`](https://lncd.github.io/lncdtools/shell/#waitforjobs), some care will need to be taken to not hit a R parallel package socket port conflict.
1. the easiest solution is to disable internal parallelization:  `ROI_TempCorr.R ... -njobs 1`.
1.  Alternatively, you can manually set the port for each `ROI_TempCorr.R`. Consider
```bash 
ROI_TempCorr.R ... -port "$((11290 + $(pgrep -caf ROI_TempCorr) ))"
```


## FYI OSS

The code is "for your information." There are no plans (or avaiable resources) to support external usage.
