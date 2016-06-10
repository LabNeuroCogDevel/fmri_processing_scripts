#!/usr/bin/env Rscript

#script to pull together FSL FEAT level 1 runs into an AFNI BRIK+HEAD format for review
source("R_helper_functions.R")

printHelp <- function() {
    #to do
}

#read in command line arguments.
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0L) {
  message("feat_lvl1_to_afni expects a single .feat directory from a level 1 analysis -feat <directory>.\n")
  printHelp()
  quit(save="no", 1, FALSE)
}

argpos <- 1
while (argpos <= length(args)) {
  if (args[argpos] == "-feat") {
    featdir <- args[argpos + 1] #name of preprocessed fMRI data
    stopifnot(file.exists(featdir))
    argpos <- argpos + 2
  } else {
    stop("Not sure what to do with argument: ", args[argpos])
  }
}

setwd(featdir)

outfilename <- "feat_stats"

#inside the stats directory we will have pes, copes, varcopes, and zstats
#for now, ignore fstats, zfstats, res4d, and threshac1

zfiles <- list.files("stats", pattern="zstat.*\\.nii.*", full.names=TRUE)
statnums <- as.numeric(sub(".*zstat(\\d+)\\.nii.*", "\\1", zfiles, perl=TRUE))
nstats <- length(zfiles)

#lookup names of parameter estimates

tcatcall <- paste("3dTcat -overwrite -prefix", outfilename)
zbriks <- c()
for (s in 1:nstats) {
    copefile <- sub("zstat", "cope", zfiles[s], fixed=TRUE)
    varcopefile <- sub("zstat", "varcope", zfiles[s], fixed=TRUE)
    zbriks <- c(zbriks, s*3 - 1) #triplets with zstat in third position. subtract 1 because AFNI uses 0-based indexing
    tcatcall <- paste(tcatcall, copefile, varcopefile, zfiles[s])
}

#design.con contains names of contrasts
dcon <- readLines("design.con")
connames <- sub("/ContrastName\\d+\\s+([\\w_.]+).*", "\\1", grep("/ContrastName", dcon, value=TRUE), perl=TRUE)

#concatenate stat images
runAFNICommand(tcatcall, afnidir="/opt/aci/sw/afni/16.0.00/bin")

#now rework AFNI header to correct the labels and add z-stat info
briknames <- paste(rep(connames,each=3), c("coef", "var", "z"), sep="_", collapse=" ")

#add this to zstat images
refitcall <- paste0("3drefit -fbuc ", paste("-substatpar", zbriks, "fizt", collapse=" "), " -relabel_all_str '", briknames, "' ", outfilename, "+tlrc") 

runAFNICommand(refitcall, afnidir="/opt/aci/sw/afni/16.0.00/bin")

