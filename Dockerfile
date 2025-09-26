FROM debian:trixie-slim

COPY --from=afni/afni_make_build:AFNI_25.2.08 \
   /opt/afni/install/1dBport \
   /opt/afni/install/1dcat \
   /opt/afni/install/1d_tool.py \
   /opt/afni/install/1dtranspose \
   /opt/afni/install/3dBandpass \
   /opt/afni/install/3dBrickStat \
   /opt/afni/install/3dbucket \
   /opt/afni/install/3dcalc \
   /opt/afni/install/3dcopy \
   /opt/afni/install/3dDeconvolve \
   /opt/afni/install/3dDespike \
   /opt/afni/install/3dDetrend \
   /opt/afni/install/3dinfo \
   /opt/afni/install/3dmaskave \
   /opt/afni/install/3dmaskSVD \
   /opt/afni/install/3dmask_tool \
   /opt/afni/install/3dNotes \
   /opt/afni/install/3drefit \
   /opt/afni/install/3dREMLfit \
   /opt/afni/install/3dresample \
   /opt/afni/install/3dSkullStrip \
   /opt/afni/install/3dSynthesize \
   /opt/afni/install/3dTcat \
   /opt/afni/install/3dTproject \
   /opt/afni/install/3dTstat \
   /opt/afni/install/3dUnifize \
   /opt/afni/install/3dvolreg \
   /opt/afni/install/3dWarp \
   /opt/afni/install/3dZcutup \
   /opt/afni/install/3dUndump \
   /opt/afni/install/libf2c.so \
   /opt/afni/install/libmri.so \
   /usr/bin/

RUN apt update -y \
  && apt-get -y install --no-install-recommends \
               dcm2niix bc jq libexpat1 \
               python3-nibabel python3-nipy python3-pip \
               r-base-core r-cran-pracma r-cran-orthopolynom \
               bats \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/

# octave without X11. not this easy:
#   && apt-get install -y libhdf5-310 libaec0 libsz2 \
#   && apt download octave \
#   && dpkg -i ./octave*.deb --ignore-depends=libportaudio2,libqscintilla2-qt6-15,libqt6core5compat6,libqt6core6t64,libqt6gui6,libqt6help6,libqt6network6,libqt6opengl6,libqt6openglwidgets6,libqt6printsupport6,libqt6widgets6,libqt6xml6,libsndfile1,libx11-6 \
#   && rm ./ocatave*.deb \
# 'octave --no-gui': error shared libraries: libGraphicsMagick++-Q16.so.12

ENV MPLBACKEND=Agg
RUN python3 -m pip install matplotlib --break-system-packages

ENV FSLOUTPUTTYPE=NIFTI_GZ


#ENV FSLDIR=/opt/fsl
#ENV PATH=$FSLDIR/bin:$PATH
## fsl-avwutils has fslmaths
#RUN conda create \
#  -c https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/public/ \
#  -c conda-forge                                              \
#  -p $FSLDIR \
#  fsl-flirt fsl-fnirt fsl-fast4 fsl-mcflirt fsl-avwutils fsl-susan fsl-melodic fsl-fugue 
#
## total size 2.35GB !!

ENV FSLDIR=/usr

# still MIA
# $FSL_DIR/etc/flirtsch/
#
# /opt/conda/envs/fmriprep/bin/fsl_motion_outliers \
# /opt/conda/envs/fmriprep/bin/fsl_tsplot \
# /opt/conda/envs/fmriprep/bin/melodic \
# /opt/conda/envs/fmriprep/bin/fsl_regfilt \
COPY --from=nipreps/fmriprep:25.0.0 \
  /opt/conda/envs/fmriprep/bin/mcflirt \
  /opt/conda/envs/fmriprep/bin/fugue \
  /opt/conda/envs/fmriprep/bin/fast \
  /opt/conda/envs/fmriprep/bin/bet \
  /opt/conda/envs/fmriprep/bin/bet2 \
  /opt/conda/envs/fmriprep/bin/flirt \
  /opt/conda/envs/fmriprep/bin/fnirt \
  /opt/conda/envs/fmriprep/bin/fslhd \
  /opt/conda/envs/fmriprep/bin/fslmaths \
  /opt/conda/envs/fmriprep/bin/fslmerge \
  /opt/conda/envs/fmriprep/bin/fslorient \
  /opt/conda/envs/fmriprep/bin/fsl_prepare_fieldmap \
  /opt/conda/envs/fmriprep/bin/fslreorient2std \
  /opt/conda/envs/fmriprep/bin/fslroi \
  /opt/conda/envs/fmriprep/bin/fslsmoothfill \
  /opt/conda/envs/fmriprep/bin/fslsplit \
  /opt/conda/envs/fmriprep/bin/fslstats \
  /opt/conda/envs/fmriprep/bin/fslval \
  /opt/conda/envs/fmriprep/bin/avscale \
  /opt/conda/envs/fmriprep/bin/fslswapdim \
  /opt/conda/envs/fmriprep/bin/imtest \
  /opt/conda/envs/fmriprep/bin/remove_ext \
  /opt/conda/envs/fmriprep/bin/tmpnam \
 /usr/bin

# ls /usr/bin/{fsl*,flirt,fnirt,mcflirt,bet2,tmpnam,avscale} | xargs ldd |& grep not
COPY --from=nipreps/fmriprep:25.0.0 \
  /opt/conda/envs/fmriprep/lib/libfsl-newimage.so \
  /opt/conda/envs/fmriprep/lib/libfsl-miscmaths.so \
  /opt/conda/envs/fmriprep/lib/libfsl-NewNifti.so \
  /opt/conda/envs/fmriprep/lib/libfsl-utils.so \
  /opt/conda/envs/fmriprep/lib/libfsl-cprob.so \
  /opt/conda/envs/fmriprep/lib/libfsl-znz.so \
  /opt/conda/envs/fmriprep/lib/libfsl-warpfns.so \
  /opt/conda/envs/fmriprep/lib/libfsl-basisfield.so \
  /opt/conda/envs/fmriprep/lib/libfsl-meshclass.so \
  /usr/lib/x86_64-linux-gnu/

# TODO: this needs to come from an online source
#COPY /opt/ni_tools/fsl_6//etc/flirtsch /usr/etc/fslconf/

# fsl.sh wanted by flirt. sets env. hopefully nothing needed. empty file is okay
# fsl version isn't recorded in nipreps. but is at least 6.0.x
RUN mkdir -p /usr/etc/fslconf/ \
   && touch /usr/etc/fslconf/fsl.sh \
   && echo 6.0 > /usr/etc/fslverion \
   && ln -s /usr/bin/python3 /usr/bin/fslpython \
   && ln -s /usr/bin/python3 /usr/bin/python
# python for 1d_tool.py

# need many R packages for ROI_TempCorr.R.
# oro.nifti will need to be compiled and copied in. not in debian repos
# RUN apt update -y \
#   && apt-get -y install --no-install-recommends \
#                r-cran-forcast r-cran-matrix r-cran-plyr \
#   && apt-get autoremove -y \
#   && apt-get clean -y \
#   && apt-get autoclean -y \
#   && rm -rf /var/lib/apt/lists/


ENV PATH=/opt/fmri_processing_scripts:$PATH
COPY ./ /opt/fmri_processing_scripts
