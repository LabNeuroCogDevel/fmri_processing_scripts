# MRI Preprocessing

## Tools

  * `preprocessMprage`
  * `preprocessFunctional`
    * `sliceMotion4d`
  * `ROI_TempCorr.R`


## Depends
see [citations](./citations.txt) and `preprocessFunctional -check_dependencies`

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
 * [fmriprep](https://fmriprep.readthedocs.io/en/stable/index.html), [clpipe](https://github.com/cohenlabUNC/clpipe)
 * [afni\_proc](https://afni.nimh.nih.gov/pub/dist/doc/program_help/afni_proc.py.html)

## FYI OSS

The code is "for your information." There are no plans (or avaiable resources) to support external usage.
