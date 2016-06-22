#!/usr/bin/env Rscript

##script to pull together FSL FEAT level 2 runs into an AFNI BRIK+HEAD format for review
##Note: this is largely a simple wrapper around the first-level conversion script
##For L2 analyses, the individual cope*.feat directories have the L1 structure and can be digested accordingly

printHelp <- function() {
    #to do
}

#read in command line arguments.
args <- commandArgs(trailingOnly = FALSE)
Sys.setenv(AFNIDIR="/opt/aci/sw/afni/16.0.00/bin")

scriptpath <- dirname(sub("--file=", "", grep("--file=", args, fixed=TRUE, value=TRUE), fixed=TRUE))
argpos <- grep("--args", args, fixed=TRUE)
args <- args[(argpos+1):length(args)]
source(file.path(scriptpath, "R_helper_functions.R"))

if (length(args) == 0L) {
  message("feat_lvl2_to_afni expects a single .gfeat directory from a level 2 analysis -gfeat_dir <directory>.\n")
  printHelp()
  quit(save="no", 1, FALSE)
}

outfilename <- "gfeat_stats"
auxfilename <- "gfeat_aux"

argpos <- 1
while (argpos <= length(args)) {
    if (args[argpos] == "-gfeat_dir") {
        gfeatdir <- args[argpos + 1] #name of preprocessed fMRI data
        stopifnot(file.exists(gfeatdir))
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

setwd(gfeatdir)

##find cope directories
copedirs <- grep("/cope[0-9]+\\.feat", list.dirs(path=gfeatdir, full.names=TRUE, recursive=FALSE), value=TRUE, perl=TRUE)
copeafni <- c()
for (d in 1:length(copedirs)) {
    ##run the L1 -> AFNI conversion for each separate cope
    system(paste("feat_lvl1_to_afni.R -feat_dir", copedirs[d]))
    copename <- readLines(file.path(copedirs[d], "design.lev")) #contains the L2 effect name (e.g., clock_onset)

    afniout <- file.path(copedirs[d], "feat_stats+tlrc")
    briklabels <- runAFNICommand(paste("3dinfo -label", afniout), intern=TRUE)
    briklabels <- paste(copename, strsplit(briklabels, "|", fixed=TRUE)[[1]], sep="_", collapse=" ")
    
    ##need to add prefix for each cope to make the stats unique
    retcode <- runAFNICommand(paste0("3drefit -relabel_all_str '", briklabels, "' ", afniout))

    ##for now, eliminate the aux file
    system(paste("rm", file.path(copedirs[d], "feat_aux+tlrc*")))

    copeafni <- c(copeafni, afniout)
}

#glue together the stats files
retcode <- runAFNICommand(paste("3dTcat -overwrite -prefix", outfilename, paste(copeafni, collapse=" ")))

if (file.exists(paste0(outfilename, "+tlrc.BRIK"))) {
    system(paste0("gzip ", outfilename, "+tlrc.BRIK"))
}

system(paste("rm", paste0(copeafni, "*", collapse=" ")))
