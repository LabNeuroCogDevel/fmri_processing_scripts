#!/usr/bin/Rscript

args <- commandArgs(TRUE)

if (length(args) == 0)
  cat ("computeMode.R usage: computeMode.R 4dFMRIFile brainMaskFile scaleMode\n")

suppressMessages(library(oro.nifti))
suppressMessages(library(stats))
suppressMessages(library(ftnonpar))

#for testing
#fmriFilename <- "nfswktmd_10128_5.nii"
#maskFilename <- "wktmd_10128_98_2_mask.nii.gz"
#scaleTo <- 1000

fmriFilename <- args[1]

#determine whether nifti or afni
isNifti <- function(fn) grepl(".*(\\.nii|\\.nii\\.gz)+$", fn, perl=TRUE)
isAfni <- function(fn) grepl("[^\\+]+\\+(tlrc|orig|acpc)+\\.(HEAD|BRIK|BRIK\\.gz)+$", fn, perl=TRUE)

fmriAfni <- isAfni(fmriFilename)
fmriNifti <- isNifti(fmriFilename)

if (!fmriAfni && !fmriNifti) stop("Cannot determine fmri file type from file name: ", fmriFilename)

mask <- FALSE
if (length(args) > 1) {
   mask <- TRUE
   maskFilename <- args[2]
   maskAfni <- isAfni(maskFilename)
   maskNifti <- isNifti(maskFilename)
}

#if a third parameter is given
if (length(args) > 2) {
  scaleTo <- as.numeric(args[3])
} else {
  scaleTo <- 1
}


if (file.exists(fmriFilename)) {
  if (fmriNifti) {
    nif <- readNIfTI(fmriFilename)@.Data
  } else if (fmriAfni) {
    nif <- readAFNI(fmriFilename)@.Data
  }

  #browser()
  
  if (mask && file.exists(maskFilename)) {
    if (maskAfni)
      maskMat <- readAFNI(maskFilename)@.Data
    else if (maskNifti)
      maskMat <- readNIfTI(maskFilename)@.Data
    
    #apply mask at each volume in 4d time series
    nif <- apply(nif, 4, function(submat) {
      submat[which(maskMat==0)] <- NA_real_
      submat
    })

    nif <- as.vector(nif)
  } else {
    #if mask not provided, avoid problem of 0 being the mode because of many non-brain voxels
    nif <- nif[which(nif != 0)]
  }
  
  #density estimate of mode
  dens <- density(na.omit(nif), n=1024)
  modalVal <- dens$x[dens$y==max(dens$y)]

  #note that the above is giving low estimates for preprocessFunctional data, probably of low intensity voxels at the edge
  #dens$x[dens$y >= quantile(dens$y, 0.95)]
  
  #this is just one approach to mode estimation with continuous data

  if (scaleTo == 1) {
    cat(modalVal, "\n")
  } else {
    cat(scaleTo/modalVal, "\n")
  }
   
} else {
  cat("-1\n")
}
