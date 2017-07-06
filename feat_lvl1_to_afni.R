#!/usr/bin/env Rscript

#script to pull together FSL FEAT level 1 runs into an AFNI BRIK+HEAD format for review
printHelp <- function() {
  #to do
}

#read in command line arguments.
args <- commandArgs(trailingOnly = FALSE)
##Sys.setenv(AFNIDIR="/opt/aci/sw/afni/16.0.00/bin")
Sys.setenv(AFNIDIR="/opt/aci/sw/afni/17.0.02/bin")

scriptpath <- dirname(sub("--file=", "", grep("--file=", args, fixed=TRUE, value=TRUE), fixed=TRUE))
argpos <- grep("--args", args, fixed=TRUE)
args <- args[(argpos+1):length(args)]
source(file.path(scriptpath, "R_helper_functions.R"))

if (length(args) == 0L) {
  message("feat_lvl1_to_afni expects a single .feat directory from a level 1 analysis -feat_dir <directory>.\n")
  printHelp()
  quit(save="no", 1, FALSE)
}

outfilename <- "feat_stats"
auxfilename <- "feat_aux"
output_varcope <- TRUE
output_auxstats <- TRUE #thresh zstat f-stats etc.

argpos <- 1
while (argpos <= length(args)) {
  if (args[argpos] == "--feat_dir") {
    featdir <- args[argpos + 1] #name of preprocessed fMRI data
    stopifnot(file.exists(featdir))
    argpos <- argpos + 2
  } else if (args[argpos] == "--no_varcope") {
    output_varcope <- FALSE
    argpos <- argpos + 1
  } else if (args[argpos] == "--no_auxstats") {
    output_auxstats <- FALSE
    argpos <- argpos + 1
  } else if (args[argpos] == "--stat_outfile") { #name of output file for main stats file
    outfilename <- args[argpos + 1]
    argpos <- argppos + 2
  } else if (args[argpos] == "--aux_outfile") {
    auxfilename <- args[argpos + 1]
    argpos <- argpos + 2
  } else {
    stop("Not sure what to do with argument: ", args[argpos])
  }
}

setwd(featdir)

#inside the stats directory we will have pes, copes, varcopes, and zstats
zfiles <- list.files("stats", pattern="zstat[0-9]+\\.nii.*", full.names=TRUE)
statnums <- as.numeric(sub(".*zstat(\\d+)\\.nii.*", "\\1", zfiles, perl=TRUE))
nstats <- length(zfiles)

##lookup names of parameter estimates

tcatcall <- paste("3dTcat -overwrite -prefix", outfilename)
zbriks <- c()
for (s in 1:nstats) {
  copefile <- sub("zstat", "cope", zfiles[s], fixed=TRUE)
  if (output_varcope) {
    varcopefile <- sub("zstat", "varcope", zfiles[s], fixed=TRUE)
    zbriks <- c(zbriks, s*3 - 2) #triplets with zstat in second position. subtract 1 because AFNI uses 0-based indexing and 1 to put zstat as second of triplet
    tcatcall <- paste(tcatcall, copefile, zfiles[s], varcopefile)
  } else {
    zbriks <- c(zbriks, s*2 - 1) #triplets with zstat in second position. subtract 1 because AFNI uses 0-based indexing
    tcatcall <- paste(tcatcall, copefile, zfiles[s])
  }
}

#concatenate stat images
runAFNICommand(tcatcall)

#design.con contains names of contrasts
dcon <- readLines("design.con")
connames <- sub("/ContrastName\\d+\\s+([\\w_.]+).*", "\\1", grep("/ContrastName", dcon, value=TRUE), perl=TRUE)

#now rework AFNI header to correct the labels and add z-stat info
if (output_varcope) {
  briknames <- paste(rep(connames,each=3), c("coef", "z", "var"), sep="_", collapse=" ")
} else {
  briknames <- paste(rep(connames,each=2), c("coef", "z"), sep="_", collapse=" ")
}

#add this to zstat images
refitcall <- paste0("3drefit -fbuc ", paste("-substatpar", zbriks, "fizt", collapse=" "), " -relabel_all_str '", briknames, "' ", outfilename, "+tlrc") 

runAFNICommand(refitcall)

if (output_auxstats) {

  ##read auxiliary files (PEs + error)
  zbriks <- c()
  pefiles <- list.files("stats", pattern="^pe.*\\.nii.*", full.names=TRUE)
  penums <- as.numeric(sub(".*pe(\\d+)\\.nii.*", "\\1", pefiles, perl=TRUE))
  pefiles <- pefiles[order(penums)]
  findex <- 0 #0-based indexing
  tcatcall <- paste("3dTcat -overwrite -prefix", auxfilename)
  for (file in 1:length(pefiles)) {
    tcatcall <- paste(tcatcall, pefiles[file])
    findex <- findex + 1
  }

  ##add in other files
  ##thresh_zstat files
  threshzfiles <- list.files(pattern="^thresh_zstat.*\\.nii.*", full.names=TRUE)
  if (length(threshzfiles) > 0L) {    
    threshznums <- as.numeric(sub(".*thresh_zstat(\\d+)\\.nii.*", "\\1", threshzfiles, perl=TRUE))
    threshzfiles <- threshzfiles[order(threshznums)]
    for (file in 1:length(threshzfiles)) {
      tcatcall <- paste(tcatcall, threshzfiles[file])
      zbriks <- c(zbriks, findex)
      findex <- findex + 1
    }
  }
  
  zfstatfiles <- list.files("stats", pattern="zfstat.*\\.nii.*", full.names=TRUE)
  if (length(zfstatfiles) > 0L) {
    for (file in 1:length(zfstatfiles)) {
      tcatcall <- paste(tcatcall, zfstatfiles[file])
      zbriks <- c(zbriks, findex)
      findex <- findex + 1
    }
  }

  #add residuals
  if (file.exists("stats/sigmasquared.nii.gz")) {
    tcatcall <- paste(tcatcall, "stats/sigmasquareds.nii.gz")
    findex <- findex + 1
  }

  runAFNICommand(tcatcall)

  briknames <- paste(c(paste0("pe", sort(penums)), paste0("thresh_zstat", sort(threshznums)), paste0("zfstat", 1:length(zfstatfiles)), "sigmasquareds"), collapse=" ")

  #add this to zstat images
  refitcall <- paste0("3drefit -fbuc ", paste("-substatpar", zbriks, "fizt", collapse=" "), " -relabel_all_str '", briknames, "' ", auxfilename, "+tlrc")
  runAFNICommand(refitcall)
}
