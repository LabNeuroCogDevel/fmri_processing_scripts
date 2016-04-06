#!/usr/bin/env Rscript

#read in command line arguments.
#current format:
#arg 1: config file to process (default current directory)
#arg 2: number of parallel jobs (default 8)
#arg 3: folder containing MRRC reconstructed MB data (rsync from meson)
args <- commandArgs(trailingOnly = TRUE)

#TODO: Accept config file as input, source (in empty env?) and then use Sys.setenv to get things running below.

goto=Sys.getenv("loc_mrraw_root")
if (! file.exists(goto)) { stop("Cannot find directory: ", goto) }
setwd(goto)
basedir <- getwd() #root directory for processing

if (length(args) > 0L) {
    njobs <- as.numeric(args[1L])
} else {
    njobs <- 8
}

## if (length(args) > 2L) {
##     MB_src <- args[3L] #folder containing MRRC reconstructed data
## } else {
##     MB_src <- normalizePath(Sys.glob("../WPC-*_MB")) #assume that MB data are up one directory in folder called WPC-XXXX_MB
## }


library(foreach)
library(doMC)
library(iterators)

#pull in cfg environment variables from bash script
mprage_dirpattern=Sys.getenv("mprage_dirpattern")
preprocessed_dirname=Sys.getenv("preprocessed_dirname")
paradigm_name=Sys.getenv("paradigm_name")
n_expected_funcruns=Sys.getenv("n_expected_funcruns")
preproc_call=Sys.getenv("preproc_call")
MB_src=Sys.getenv("loc_mb_root")
mb_filepattern=Sys.getenv("mb_filepattern")

#optional config settings
loc_mrproc_root=Sys.getenv("loc_mrproc_root")
gre_fieldmap_dirpattern=Sys.getenv("gre_fieldmap_dirpattern")
fieldmap_cfg=Sys.getenv("fieldmap_cfg")

##All of the above environment variables must be in place for script to work properly.
if (any(c(mprage_dirpattern, preprocessed_dirname, paradigm_name, n_expected_funcruns, preproc_call) == "")) {
    stop("Script expects system environment to contain the following variables: mprage_dirpattern, preprocessed_dirname, paradigm_name, n_expected_funcruns, preproc_call")
}

##handle all mprage directories
##overload built-in list.dirs function to support pattern match
list.dirs <- function(...) {
    args <- as.list(match.call())[-1L] #first argument is call itself

    if (! "recursive" %in% names(args)) { args$recursive <- TRUE } #default to recursive
    if (! ("full.names" %in% names(args))) { args$full.names <- TRUE } #default to full names
    if (! "path" %in% names(args)) { args$path <- getwd() #default to current directory
                                 } else { args$path <- eval(args$path) }
    args$include.dirs <- TRUE

    flist <- do.call(list.files, args)

    oldwd <- getwd()
    if (args$full.names == FALSE) {
        #cat("path: ", args$path, "\n")
        setwd(args$path)
    }
    ##ensure that we only have directories (no files)
    ##use unlist to remove any NULLs from elements that are not directories
    dlist <- unlist(sapply(flist, function(x) { if (file.info(x)$isdir) { x } else { NULL } }, USE.NAMES = FALSE))
    setwd(oldwd)
    return(dlist) #will be null if no matches
}

##find original mprage directories to rename
##mprage_dirs <- list.dirs(pattern=mprage_dirpattern)

##much faster than above because can control recursion depth
mprage_dirs <- system(paste0("find $PWD -iname \"", mprage_dirpattern, "\" -type d -mindepth 2 -maxdepth 2"), intern=TRUE)

##removing rename of mprage directories in MR_Raw to allow for a simple/pristine rsync
##mprage is now renamed at the time it is copied into MR_Proc
##if (length(mprage_dirs) > 0L) {
##    cat("Renaming original mprage directories to \"mprage\"\n")
##    for (d in mprage_dirs) {
##        mdir <- file.path(dirname(d), "mprage")
##        file.rename(d, mdir) #rename to mprage
##    }
##}

##find all renamed mprage directories for processing
##use beginning and end of line markers to force exact match
##use getwd to force absolute path since we setwd below
##mprage_dirs <- list.dirs(pattern="^mprage$", path=getwd())

##faster than above
##mprage_dirs <- system("find $PWD -mindepth 2 -maxdepth 2 -type d -iname mprage", intern=TRUE)

registerDoMC(njobs) #setup number of jobs to fork

##for (d in mprage_dirs) {
f <- foreach(d=mprage_dirs, .inorder=FALSE) %dopar% {
    subid <- basename(dirname(d))
    outdir <- file.path(loc_mrproc_root, subid)
    if (!file.exists(outdir)) { dir.create(outdir, showWarnings=FALSE, recursive=TRUE) } #create preprocessed folder if absent
    
    if (!file.exists(file.path(outdir, "mprage"))) { system(paste("cp -Rp", d, file.path(outdir, "mprage"))) } #copy untouched mprage to processed directory
    setwd(file.path(outdir, "mprage"))
    
    #call preprocessmprage
    if (file.exists(".mprage_complete")) {
        return("complete") #skip completed mprage directories
    } else {
        script_args <- "-delete_dicom archive -template_brain MNI_2mm -cleanup -template_brain MNI_2mm"
        if (file.exists("mprage.nii.gz")) { script_args <- paste(script_args, "-nifti mprage.nii.gz") }
        
        ret_code <- system2("preprocessMprage", script_args, stderr="preprocessMprage_stderr", stdout="preprocessMprage_stdout")
        if (ret_code != 0) { stop("preprocessMprage failed in directory: ", file.path(outdir, "mprage")) }

        #echo current date/time to .mprage_complete to denote completed preprocessing
        sink(".mprage_complete")
        cat(as.character(Sys.time()))
        sink()

        if (file.exists("need_analyze")) { unlink("need_analyze") } #remove dummy file
        if (file.exists("analyze")) { unlink("analyze") } #remove dummy file

        if (file.exists("mprage_bet.nii.gz")) {
            file.symlink("mprage_bet.nii.gz", "mprage_brain.nii.gz") #symlink to _brain for compatibility with FEAT/FSL
        }
    }
    return(d)
}

#get list of subject directories in root directory
subj_dirs <- list.dirs(path=basedir, recursive=FALSE)

#make run processing parallel, not subject processing
#f <- foreach(d=subj_dirs, .inorder = FALSE) %dopar% {
all_funcrun_dirs <- list()
mb_src_queue <- c() #reconstructed MB files to be copied
mb_dest_queue <- c() #destinations for MB NIfTIs

for (d in subj_dirs) {
    cat("Processing subject: ", d, "\n")
    setwd(d)

    subid <- basename(d)

    #define root directory for subject's processed data
    if (loc_mrproc_root == "") {
        outdir <- file.path(d, preprocessed_dirname) #e.g., /Volumes/Serena/MMClock/MR_Raw/10637/MBclock_recon
    } else {
        outdir <- file.path(loc_mrproc_root, subid, preprocessed_dirname) #e.g., /Volumes/Serena/MMClock/MR_Proc/10637/native_nosmooth
    }

    #determine directories for fieldmap if using
    apply_fieldmap <- FALSE
    fmdirs <- NULL
    magdir <- phasedir <- NA_character_ #reduce risk of accidentally carrying over fieldmap from one subject to next in loop
    if (gre_fieldmap_dirpattern != "" && fieldmap_cfg != "") {
        ##determine phase versus magnitude directories for fieldmap
        ##in runs so far, magnitude comes first. preprocessFunctional should handle properly if we screw this up...
        fmdirs <- sort(normalizePath(Sys.glob(file.path(d, gre_fieldmap_dirpattern))))
        if (length(fmdirs) == 2L) {
            apply_fieldmap <- TRUE
            magdir <- file.path(loc_mrproc_root, subid, "fieldmap_magnitude")
            phasedir <- file.path(loc_mrproc_root, subid, "fieldmap_phase")
            if (!file.exists(magdir)) { system(paste("cp -Rp", fmdirs[1], magdir)) } #copy untouched magdir to processed directory
            if (!file.exists(phasedir)) { system(paste("cp -Rp", fmdirs[2], phasedir)) } #copy untouched phasedir to processed directory
            magdir <- file.path(magdir, "MR*") #add dicom pattern at end to be picked up by preprocessFunctional
            phasedir <- file.path(phasedir, "MR*")
        } else { stop("In ", d, ", number of fieldmap dirs is not 2: ", paste0(fmdirs, collapse=", ")) }
    }

    mpragedir <- file.path(loc_mrproc_root, subid, "mprage")
    if (file.exists(mpragedir)) {
        if (! (file.exists(file.path(mpragedir, "mprage_warpcoef.nii.gz")) && file.exists(file.path(mpragedir, "mprage_bet.nii.gz")) ) ) {
            stop("Unable to locate required mprage files in dir: ", mpragedir)
        }
    } else {
        stop ("Unable to locate mprage directory: ", mpragedir)
    }
    
    ##create paradigm_run1-paradigm_run8 folder structure and copy raw data
    if (!file.exists(outdir)) { #create preprocessed folder if absent
        dir.create(outdir, showWarnings=FALSE, recursive=TRUE)
    } else {
        ##preprocessed folder exists, check for .preprocessfunctional_complete files
        ##in the case of 1 functional run, we don't create subdirectories

        #take this out for now: default to rest1 for single run of rest.
        #if (n_expected_funcruns == 1) { pattern=paradigm_name
        #                            } else { pattern=paste0(paradigm_name,"[0-9]+") }
        
        extant_funcrundirs <- list.dirs(path=outdir, pattern=paste0(paradigm_name,"[0-9]+"), full.names=TRUE, recursive=FALSE)
        if (length(extant_funcrundirs) > 0L &&
            length(extant_funcrundirs) >= n_expected_funcruns &&
            all(sapply(extant_funcrundirs, function(x) { file.exists(file.path(x, ".preprocessfunctional_complete")) }))) {
            cat("   preprocessing already complete for all functional run directories\n\n")
            next
        }
    }

    #identify original reconstructed flies for this subject
    mbraw_dirs <- list.dirs(path=MB_src, recursive = FALSE, full.names=FALSE) #all original recon directories, leave off full names for grep

    #approximate grep is leading to problems with near matches!!
    #example: 11263_20140307; WPC5640_11253_20140308
    #srcmatch <- agrep(subid, mbraw_dirs, max.distance = 0.1, ignore.case = TRUE)[1L] #approximate id match in MRRC directory

    srcmatch <- grep(subid, mbraw_dirs, ignore.case = TRUE)[1L] #id match in MRRC directory
    
    if (is.na(srcmatch)) {
        warning("Unable to identify reconstructed images for id: ", subid, " in MB source directory: ", MB_src)
        next #skip this subject
    }

    srcdir <- file.path(MB_src, mbraw_dirs[srcmatch])
    cat("Matched with MB src directory: ", srcdir, "\n")
    mbfiles <- list.files(path=srcdir, pattern=mb_filepattern, full.names = TRUE) #images to copy

    if (length(mbfiles) == 0L) {
        warning("No multiband reconstructed data for: ", subid, " in MB source directory: ", MB_src)
        next #skip this subject
    }
    
    refimgs <- sub("_MB.hdr", "_ref.hdr", mbfiles, fixed=TRUE)
    ##figure out run numbers based on file names
    ##there is some variability in how files are named.
    ## v1: ep2d_MB_clock1_MB.hdr
    ## v2: ep2d_MB_clock1_8_MB.hdr (ambiguous!)
    ## v3: ep2d_MB_clock_1_MB.hdr
    ## occasionally "Eclock"?

    if (grepl("clock", mb_filepattern, fixed=TRUE)) {
        
        runnums <- sub("^.*ep2d_MB_E?clock(\\d?)_?(\\d?)_?(_FID)*.*_MB.hdr$",
                       "\\1 \\2", mbfiles, perl=TRUE, ignore.case = TRUE)

        run_split <- strsplit(runnums, "\\s+", perl=TRUE)
        run_lens <- sapply(run_split, length)

        if (any(run_lens > 1L)) {
            ##at least one file name contains two potential run numbers
            ##if any file has just one run number, duplicate it for comparison
            run_split <- lapply(run_split, function(x) { if(length(x) == 1L) { c(x,x) } else { x } } )

            ##determine which potential run number contains unique information
            R1 <- unique(sapply(run_split, "[[", 1))
            R2 <- unique(sapply(run_split, "[[", 2))

            if (length(unique(R1)) > length(unique(R2))) {
                runnums <- R1
            } else {
                runnums <- R2
            }            
        }
        
        if (length(runnums) > length(unique(runnums))) {
            print(mbfiles)
            stop("Duplicate run numbers detected.")
        }

    } else {
        runnums <- 1 #single run for rest (bit of a hack here)
    }
    
    runnums <- as.numeric(runnums)
    if (any(is.na(runnums))) { stop ("Unable to determine run numbers:", runnums) }

    cat("Detected run numbers, MB Files:\n")
    print(cbind(runnum=runnums, mbfile=mbfiles))
   
    #loop over files and setup run directories in preprocessed_dirname
    for (m in 1:length(mbfiles)) {
        #only copy data if folder does not exist
        if (!file.exists(file.path(outdir, paste0(paradigm_name, runnums[m])))) {
            dir.create(file.path(outdir, paste0(paradigm_name, runnums[m])))
            
	    ##Check for existence of unprocessed MB reconstructed NIfTI. If doesn't exist, add to copy queue
	    expectedNIfTI <- file.path(outdir, paste0(paradigm_name, runnums[m]), paste0(paradigm_name, runnums[m], ".nii.gz"))
	    if (!file.exists(expectedNIfTI)) {
	       mb_src_queue <- c(mb_src_queue, mbfiles[m])
	       mb_dest_queue <- c(mb_dest_queue, expectedNIfTI)	       
	    }
        }
    }

    #add all functional runs, along with mprage and fmap info, as a data.frame to the list
    all_funcrun_dirs[[d]] <- data.frame(funcdir=list.dirs(pattern=paste0(paradigm_name, ".*"), path=outdir, recursive = FALSE), refimgs=refimgs, 
                                        magdir=magdir, phasedir=phasedir, mpragedir=mpragedir, stringsAsFactors=FALSE)

}

#copy any needed MB reconstructed NIfTIs into place
#for now, arbitrarily copy 12 at a time
registerDoMC(12) #setup number of jobs to fork
if (length(mb_src_queue) > 0L) {
   message("Copying MB reconstructed files into place.")
   f <- foreach(fnum=1:length(mb_src_queue), .inorder=FALSE) %dopar% {
     ##use 3dcopy to copy dataset as .nii.gz
     cat(paste0(   "3dcopy \"", mb_src_queue[fnum], "\" \"", mb_dest_queue[fnum], "\"\n"))
     system(paste0("3dcopy \"", mb_src_queue[fnum], "\" \"", mb_dest_queue[fnum], "\""), wait=TRUE)     
   }
}

#rbind data frame together
all_funcrun_dirs <- do.call(rbind, all_funcrun_dirs)
row.names(all_funcrun_dirs) <- NULL

registerDoMC(njobs) #setup number of jobs to fork
#loop over directories to process
##for (cd in all_funcrun_dirs) {
f <- foreach(cd=iter(all_funcrun_dirs, by="row"), .inorder=FALSE) %dopar% {
    setwd(cd$funcdir)
    
    funcpart <- paste("-4d", Sys.glob(paste0(paradigm_name, "*.nii.gz")))
    mpragepart <- paste("-mprage_bet", file.path(cd$mpragedir, "mprage_bet.nii.gz"), "-warpcoef", file.path(cd$mpragedir, "mprage_warpcoef.nii.gz"))
    if (!is.na(cd$magdir)) {
        fmpart <- paste0("-fm_phase \"", cd$phasedir, "\" -fm_magnitude \"", cd$magdir, "\" -fm_cfg ", fieldmap_cfg)
    } else { fmpart <- "" }

    if (!is.na(cd$refimgs)) {
        refimgpart <- paste0("-func_refimg \"", cd$refimgs, "\" ")
    } else { refimgpart <- "" }
    
    ##run preprocessFunctional
    args <- paste(funcpart, mpragepart, fmpart, refimgpart, preproc_call)
    
    ret_code <- system2("preprocessFunctional", args, stderr="preprocessFunctional_stderr", stdout="preprocessFunctional_stdout")
    if (ret_code != 0) { stop("preprocessFunctional failed in directory: ", cd$funcdir) }
}
