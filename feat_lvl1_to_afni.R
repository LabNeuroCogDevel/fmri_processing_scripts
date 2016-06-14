#!/usr/bin/env Rscript

#script to pull together FSL FEAT level 1 runs into an AFNI BRIK+HEAD format for review
source("R_helper_functions.R")

printHelp <- function() {
    #to do
}

#read in command line arguments.
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0L) {
  message("feat_lvl1_to_afni expects a single .feat directory from a level 1 analysis -feat_dir <directory>.\n")
  printHelp()
  quit(save="no", 1, FALSE)
}

outfilename <- "feat_stats"
auxfilename <- "feat_aux"

argpos <- 1
while (argpos <= length(args)) {
    if (args[argpos] == "-feat_dir") {
        featdir <- args[argpos + 1] #name of preprocessed fMRI data
        stopifnot(file.exists(featdir))
        argpos <- argpos + 2
    } else if (args[argpos] == "-stat_outfile") { #name of output file for main stats file
        outfilename <- args[argpos + 1]
        argpos <- argppos + 2
    } else if (args[argpos] == "-aux_outfile") {
        auxfilename <- args[argpos + 1]
        argpos <- argpos + 2
    } else {
        stop("Not sure what to do with argument: ", args[argpos])
    }
}

setwd(featdir)

#inside the stats directory we will have pes, copes, varcopes, and zstats
zfiles <- list.files("stats", pattern="zstat.*\\.nii.*", full.names=TRUE)
statnums <- as.numeric(sub(".*zstat(\\d+)\\.nii.*", "\\1", zfiles, perl=TRUE))
nstats <- length(zfiles)

##lookup names of parameter estimates

tcatcall <- paste("3dTcat -overwrite -prefix", outfilename)
zbriks <- c()
for (s in 1:nstats) {
    copefile <- sub("zstat", "cope", zfiles[s], fixed=TRUE)
    varcopefile <- sub("zstat", "varcope", zfiles[s], fixed=TRUE)
    zbriks <- c(zbriks, s*3 - 1) #triplets with zstat in third position. subtract 1 because AFNI uses 0-based indexing
    tcatcall <- paste(tcatcall, copefile, varcopefile, zfiles[s])
}

#concatenate stat images
runAFNICommand(tcatcall)

#design.con contains names of contrasts
dcon <- readLines("design.con")
connames <- sub("/ContrastName\\d+\\s+([\\w_.]+).*", "\\1", grep("/ContrastName", dcon, value=TRUE), perl=TRUE)

#now rework AFNI header to correct the labels and add z-stat info
briknames <- paste(rep(connames,each=3), c("coef", "var", "z"), sep="_", collapse=" ")

#add this to zstat images
refitcall <- paste0("3drefit -fbuc ", paste("-substatpar", zbriks, "fizt", collapse=" "), " -relabel_all_str '", briknames, "' ", outfilename, "+tlrc") 

runAFNICommand(refitcall)

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
threshznums <- as.numeric(sub(".*thresh_zstat(\\d+)\\.nii.*", "\\1", threshzfiles, perl=TRUE))
threshzfiles <- threshzfiles[order(threshznums)]
for (file in 1:length(threshzfiles)) {
    tcatcall <- paste(tcatcall, threshzfiles[file])
    zbriks <- c(zbriks, findex)
    findex <- findex + 1
}

zfstatfiles <- list.files("stats", pattern="zfstat.*\\.nii.*", full.names=TRUE)

for (file in 1:length(zfstatfiles)) {
    tcatcall <- paste(tcatcall, zfstatfiles[file])
    zbriks <- c(zbriks, findex)
    findex <- findex + 1
}

#add residuals
tcatcall <- paste(tcatcall, "stats/sigmasquareds.nii.gz")
findex <- findex + 1

runAFNICommand(tcatcall)

briknames <- paste(c(paste0("pe", sort(penums)), paste0("thresh_zstat", sort(threshznums)), paste0("zfstat", 1:length(zfstatfiles)), "sigmasquareds"), collapse=" ")

#add this to zstat images
refitcall <- paste0("3drefit -fbuc ", paste("-substatpar", zbriks, "fizt", collapse=" "), " -relabel_all_str '", briknames, "' ", auxfilename, "+tlrc")
runAFNICommand(refitcall)
