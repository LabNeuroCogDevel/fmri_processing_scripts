#!/usr/bin/env Rscript
#This is a script for automated preprocessing of functional MRI data and their corresponding structural scans.
#It expects to find several key configuration parameters in the system environment at the time of execution.
#These are typically handled upstream of the script by autopreproc, which sources a cfg file to initialize these variables.
#The basic structure is that files are copied from a raw source location to a processed destination location.
#Strutural scans are then processed using preprocessMprage and functional scans are then processed by preprocessFunctional.
#The script uses the foreach/dopar approach with doMC as the backend to make processing embarrassingly parallel.

#The only parameter expected on the command line is the number of jobs to run in parallel, 
#and if not specified, the script defaults to 8.

args <- commandArgs(trailingOnly = TRUE)
options(width=180)
#location of raw MR data
goto=Sys.getenv("loc_mrraw_root")
if (! file.exists(goto)) { stop("Cannot find directory: ", goto) }
setwd(goto)
basedir <- getwd() #root directory for processing

if (length(args) > 0L) {
    njobs <- as.numeric(args[1L])
} else {
    njobs <- 8
}

#load required libraries
library(foreach)
library(doMC)
library(iterators)

#pull in cfg environment variables from bash script
mprage_dirpattern = Sys.getenv("mprage_dirpattern") #wildcard pattern defining names of relevant structural scans
mprage_dicompattern = Sys.getenv("mprage_dicompattern")
functional_dirpattern = Sys.getenv("functional_dirpattern")
functional_dicompattern = Sys.getenv("functional_dicompattern")

preprocessed_dirname = Sys.getenv("preprocessed_dirname") #name of subdirectory output for each processed fMRI scan
paradigm_name = Sys.getenv("paradigm_name") #name of paradigm used as a prefix for processed run directories
n_expected_funcruns = Sys.getenv("n_expected_funcruns") #number of runs per subject of the task
preproc_call = Sys.getenv("preproc_call") #parameters passed forward to preprocessFunctional
preprocessMprage_call = Sys.getenv("preprocessMprage_call") #parameters passed forward to preprocessMprage
MB_src = Sys.getenv("loc_mb_root") #Name of directory containing offline-reconstructed fMRI data (only relevant for Tae Kim sequence Pittburgh data)
mb_filepattern = Sys.getenv("mb_filepattern") #Wildcard pattern of MB reconstructed data within MB_src
useOfflineMB = ifelse(nchar(MB_src) > 0, TRUE, FALSE) #whether to use offline-reconstructed hdr/img files as preprocessing starting point
proc_freesurfer = as.numeric(Sys.getenv("proc_freesurfer")) #whether to run the structural scan through FreeSurferPipeline after preprocessMprage

fs_subjects_dir = NULL
if (is.na(proc_freesurfer)) {
    proc_freesurfer <- FALSE
} else if (proc_freesurfer == 1) {
    proc_freesurfer <- TRUE
    fs_subjects_dir <- Sys.getenv("SUBJECTS_DIR")
    freesurfer_id_prefix = Sys.getenv("freesurfer_id_prefix") #string to prepend onto subject id for uniqueness
} else {
    proc_freesurfer <- FALSE #should I trap other possibilities here?    
}

proc_functional = as.numeric(Sys.getenv("proc_functional")) #whether to run preprocessFunctional (or just terminate after structurals)
if (is.na(proc_functional)) {
    proc_functional <- FALSE
} else if (proc_functional == 1) {
    proc_functional <- TRUE
} else {
    proc_functional <- FALSE #should I trap other possibilities here?    
}

detect_refimg = as.numeric(Sys.getenv("detect_refimg")) #whether to pass raw directory to preprocessFunctional in order to detect refimg
if (is.na(detect_refimg)) {
    detect_refimg <- FALSE
} else if (detect_refimg == 1) {
    detect_refimg <- TRUE
} else {
    detect_refimg <- FALSE #should I trap other possibilities here?    
}


#setup default parameters
if (mprage_dicompattern == "") { mprage_dicompattern = "MR*" }
if (functional_dicompattern == "") { functional_dicompattern = "MR*" }
if (preprocessMprage_call == "") { preprocessMprage_call = paste0("-delete_dicom archive -template_brain MNI_2mm") }

#add dicom pattern into the mix
preprocessMprage_call <- paste0(preprocessMprage_call, " -dicom \"", mprage_dicompattern, "\"")
usegradunwarp=grepl("-grad_unwarp\\s+", preprocessMprage_call, perl=TRUE)
gradunwarpsuffix=""
if (usegradunwarp) {
    message("Using structural -> MNI warp coefficients that include gradient undistortion: _withgdc.")
    message("Also: assuming that all images provided to preprocessFunctional (incl. mprage and fieldmap) are not corrected for gradient disortion")
    gradunwarpsuffix <- "_withgdc"
} 

#optional config settings
loc_mrproc_root = Sys.getenv("loc_mrproc_root")
gre_fieldmap_dirpattern = Sys.getenv("gre_fieldmap_dirpattern")
fieldmap_cfg = Sys.getenv("fieldmap_cfg")
useFieldmap = ifelse(nchar(gre_fieldmap_dirpattern) > 0, TRUE, FALSE) #whether to include fieldmaps in processing

##All of the above environment variables must be in place for script to work properly.
if (any(c(mprage_dirpattern, preprocessed_dirname, paradigm_name, n_expected_funcruns, preproc_call) == "")) {
    stop("Script expects system environment to contain the following variables: mprage_dirpattern, preprocessed_dirname, paradigm_name, n_expected_funcruns, preproc_call")
}

##convert expected runs to numeric
n_expected_funcruns <- as.numeric(n_expected_funcruns)

##output configuration parameters for this run
cat("---------\nSummary of preprocessAll.R configuration:\n---------\n")
cat("  Source directory for raw MRI files:", goto, "\n")
cat("  Process structurals through FreeSurferPipeline: ", as.character(proc_freesurfer), "\n")
cat("  Process functional data: ", as.character(proc_functional), "\n")
cat("  Destination root directory for processed MRI files:", loc_mrproc_root, "\n")
cat("  Destination subdirectory for each subject:", preprocessed_dirname, "\n")
cat("  Name of paradigm folder:", paradigm_name, ", expected runs:", n_expected_funcruns, "\n")
if (useOfflineMB) {
    cat("  Using offline-reconstructed multiband data (Tae Kim Pittsburgh sequence)\n")
    cat("  Expected name of offline-reconstructed multiband files:", mb_filepattern, "\n")
    cat("  Directory containing MB-reconstructed files:", MB_src, "\n")
}
if (useFieldmap) {
    cat("  Using GRE fieldmap correction\n")
    cat("  Expected name of GRE fieldmap source directories:", gre_fieldmap_dirpattern, "\n")
    cat("  Fieldmap configuration file:", fieldmap_cfg, "\n")
}
cat("--------\n\n")

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

##Much faster on *nix-friendly systems than above because can control recursion depth
##Note that the depth of 2 assumes a structure such as Project_Dir/SubjectID/mprage_dir where each subject has a single directory
mprage_dirs <- system(paste0("find $PWD -mindepth 2 -maxdepth 2 -iname \"", mprage_dirpattern, "\" -type d"), intern=TRUE)

##find all renamed mprage directories for processing
##use beginning and end of line markers to force exact match
##use getwd to force absolute path since we setwd below
##mprage_dirs <- list.dirs(pattern="^mprage$", path=getwd())

##faster than above
##mprage_dirs <- system("find $PWD -mindepth 2 -maxdepth 2 -type d -iname mprage", intern=TRUE)

registerDoMC(njobs) #setup number of jobs to fork

##figure out which mprage scans need to be processed
##then process in parallel below
mprage_toprocess <- c()
for (d in mprage_dirs) {
    subid <- basename(dirname(d))
    outdir <- file.path(loc_mrproc_root, subid)
    #should probably just use short circuit || here instead of compound if elses
    if (!file.exists(outdir)) {
        ##create preprocessed folder if absent
        dir.create(outdir, showWarnings=FALSE, recursive=TRUE)
        mprage_toprocess <- c(mprage_toprocess, d)
    } else if (!file.exists(file.path(outdir, "mprage"))) {
        #output directory exists, but mprage subdirectory does not
        mprage_toprocess <- c(mprage_toprocess, d)
    } else if (!file.exists(file.path(outdir, "mprage", ".preprocessmprage_complete"))) {
        #mprage subdirectory exists, but complete file does not
        mprage_toprocess <- c(mprage_toprocess, d)
    }
}

cat("Mprage directories to be processed:\n")
print(mprage_toprocess)

f <- foreach(d=mprage_toprocess, .inorder=FALSE) %dopar% {
    subid <- basename(dirname(d))
    outdir <- file.path(loc_mrproc_root, subid)
    
    if (!file.exists(file.path(outdir, "mprage"))) { system(paste("cp -Rp", d, file.path(outdir, "mprage"))) } #copy untouched mprage to processed directory
    setwd(file.path(outdir, "mprage"))
    
    #call preprocessmprage
    if (file.exists(".preprocessmprage_complete")) {
        #this should never fire given logic above
        return("complete") #skip completed mprage directories
    } else {
        if (file.exists("mprage.nii.gz")) {
            preprocessMprage_call = sub("-dicom\\s+\\S+\\s+", "", preprocessMprage_call, perl=TRUE) #strip out call to dicom
            preprocessMprage_call <- paste(preprocessMprage_call, "-nifti mprage.nii.gz")
        }
        
        ret_code <- system2("preprocessMprage", preprocessMprage_call, stderr="preprocessMprage_stderr", stdout="preprocessMprage_stdout")
        if (ret_code != 0) { stop("preprocessMprage failed in directory: ", file.path(outdir, "mprage")) }

        #echo current date/time to .preprocessmprage_complete to denote completed preprocessing
        #NB: newer versions of preprocessMprage (Nov2016 and beyond) handle this internally
        if (!file.exists(".preprocessmprage_complete")) {
            sink(".preprocessmprage_complete"); cat(as.character(Sys.time())); sink()
        }

        if (file.exists("need_analyze")) { unlink("need_analyze") } #remove dummy file
        if (file.exists("analyze")) { unlink("analyze") } #remove dummy file

    }
    return(d)
}

if (proc_freesurfer) {
    #look for which subjects are already complete
    fs_toproc <- c()
    ids_toproc <- c()
    for (d in mprage_dirs) {
        subid <- basename(dirname(d))
        outdir <- file.path(loc_mrproc_root, subid)
        
        if (!file.exists(file.path(outdir, "mprage"))) {
            message("Cannot locate processed mprage data for: ", outdir)
        } else if (!file.exists(file.path(outdir, "mprage", ".preprocessmprage_complete"))) {
            message("Cannot locate .preprocessmprage_complete in: ", outdir)
        } else if (file.exists(file.path(fs_subjects_dir, paste0(freesurfer_id_prefix, subid)))) {
            message("Skipping FreeSurfer pipeline for subject: ", subid)
        } else {
            fs_toproc <- c(fs_toproc, file.path(outdir, "mprage"))
            ids_toproc <- c(ids_toproc, paste0(freesurfer_id_prefix, subid))
        }
    }

    if (length(fs_toproc) > 0) {
        message("About to run FreeSurfer pipeline on the following datasets:")
        print(fs_toproc)
        
        f <- foreach(d=1:length(fs_toproc), .inorder=FALSE) %dopar% {
            setwd(fs_toproc[d])
            #use the gradient distortion-corrected files if available
            t1 <- ifelse(file.exists("mprage_biascorr_postgdc.nii.gz"), "mprage_biascorr_postgdc.nii.gz", "mprage_biascorr.nii.gz")
            t1brain <- ifelse(file.exists("mprage_bet_postgdc.nii.gz"), "mprage_bet_postgdc.nii.gz", "mprage_bet.nii.gz")
            ret_code <- system2("FreeSurferPipeline", paste0("-T1 ", t1, " -T1brain ", t1brain, " -subject ", ids_toproc[d], " -subjectDir ", fs_subjects_dir),
                                stderr="FreeSurferPipeline_stderr", stdout="FreeSurferPipeline_stdout")
            if (ret_code != 0) { stop("FreeSurferPipeline failed in directory: ", fs_toproc[d]) }            
        }
    }
}

if (!proc_functional) {
    cat("Ending preprocessAll.R because proc_functional is FALSE (i.e., we are all done)\n\n")
    quit(save="no", status=0)
}

#get list of subject directories in root directory
subj_dirs <- list.dirs(path=basedir, recursive=FALSE)

#Make run processing parallel, not subject processing. This scales much better across processors
all_funcrun_dirs <- list()
mb_src_queue <- c() #reconstructed MB files to be copied
mb_dest_queue <- c() #destinations for MB NIfTIs
functional_src_queue <- c() #original run directories in MR_Raw to be copied
functional_dest_queue <- c() #destination targets of raw data

for (d in subj_dirs) {
    cat("\n------\nProcessing subject: ", d, "\n")
    setwd(d)

    subid <- basename(d)

    ##define root directory for subject's processed data
    if (loc_mrproc_root == "") {
        ##assume that we should create a subdirectory relative to the subject directory
        outdir <- file.path(d, preprocessed_dirname) #e.g., /gpfs/group/mnh5174/default/MMClock/MR_Raw/10637/MBclock_recon
    } else {
        outdir <- file.path(loc_mrproc_root, subid, preprocessed_dirname) #e.g., /gpfs/group/mnh5174/default/MMClock/MR_Proc/10637/native_nosmooth
    }

    #determine directories for fieldmap if using
    fmdirs <- NULL
    magdir <- phasedir <- NA_character_ #reduce risk of accidentally carrying over fieldmap from one subject to next in loop
    if (useFieldmap) {
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
        if (! (file.exists(file.path(mpragedir, paste0("mprage_warpcoef", gradunwarpsuffix, ".nii.gz"))) && file.exists(file.path(mpragedir, "mprage_bet.nii.gz")) ) ) {
            stop("Unable to locate required mprage files in dir: ", mpragedir)
        }
    } else {
        stop ("Unable to locate mprage directory: ", mpragedir)
    }
    
    ##create paradigm_run1-paradigm_run<N> folder structure and copy raw data
    if (!file.exists(outdir)) { #create preprocessed root folder if absent
        dir.create(outdir, showWarnings=FALSE, recursive=TRUE)
    } else {
        ##preprocessed folder exists, check for .preprocessfunctional_complete files
        extant_funcrundirs <- list.dirs(path=outdir, pattern=paste0("^", paradigm_name,"[0-9]+$"), full.names=TRUE, recursive=FALSE)
        if (length(extant_funcrundirs) > 0L &&
            length(extant_funcrundirs) >= n_expected_funcruns &&
            all(sapply(extant_funcrundirs, function(x) { file.exists(file.path(x, ".preprocessfunctional_complete")) }))) {
            cat("   preprocessing already complete for all functional run directories in: ", outdir, "\n\n")
            next
        }
    }

    #Handle the use of offline-reconstructed hdr/img files as the starting point of preprocessFunctional (Tae Kim Pittsburgh data)
    if (useOfflineMB) {
        ##identify original reconstructed flies for this subject
        mbraw_dirs <- list.dirs(path=MB_src, recursive = FALSE, full.names=FALSE) #all original recon directories, leave off full names for grep

	message("Searching for offline-reconstructed MB images")

        ##approximate grep is leading to problems with near matches!!
        ##example: 11263_20140307; WPC5640_11253_20140308
        ##srcmatch <- agrep(subid, mbraw_dirs, max.distance = 0.1, ignore.case = TRUE)[1L] #approximate id match in MRRC directory

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

        ##Note that this is only working for files with clock in the name and with the naming scheme below
        ##Should probably move this to cfg file for generality, but no motivation at the moment.
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
        
        ##loop over files and setup run directories in preprocessed_dirname
        for (m in 1:length(mbfiles)) {
            ##only copy data if folder does not exist
            if (!file.exists(file.path(outdir, paste0(paradigm_name, runnums[m])))) {
                dir.create(file.path(outdir, paste0(paradigm_name, runnums[m])))
                
                ##Check for existence of unprocessed MB reconstructed NIfTI. If doesn't exist, add to copy queue
                expectedNIfTI <- file.path(outdir, paste0(paradigm_name, runnums[m]), paste0(paradigm_name, runnums[m], ".nii.gz"))
		cat("Searching for file: ", expectedNIfTI, "\n")
                if (!file.exists(expectedNIfTI)) {
                    mb_src_queue <- c(mb_src_queue, mbfiles[m])
                    mb_dest_queue <- c(mb_dest_queue, expectedNIfTI)
                }
            }
        }

        ##add all functional runs, along with mprage and fmap info, as a data.frame to the list
        all_funcrun_dirs[[d]] <- data.frame(funcdir=list.dirs(pattern=paste0(paradigm_name, "[0-9]+$"), path=outdir, recursive = FALSE),
                                        refimgs=refimgs, magdir=magdir, phasedir=phasedir, mpragedir=mpragedir, stringsAsFactors=FALSE)

    } else {
        ##check for existing run directories and setup copy queue as needed

        funcdirs <- sort(normalizePath(Sys.glob(file.path(d, functional_dirpattern))))

        if (length(funcdirs) != n_expected_funcruns) {
            message("Cannot find the expected number of functional run directories in ", d, "for pattern", functional_dirpattern)
            message("Skipping participant for now")
            next
        }

        rundirs <- c()
        for (r in 1:n_expected_funcruns) {
            rundir <- file.path(outdir, paste0(paradigm_name, r))
            rundirs <- c(rundirs, rundir)
            if (!file.exists(rundir)) {
                ##for now, the script only handles the case where the whole directory is missing
                ##below is some scaffolding for a more sophisticated variant that checks for the unprocessed NIfTI etc.
                ##but not going to put in time to perfect it right now

                ##expectedNIfTI <- file.path(outdir, paste0(paradigm_name, r), paste0(paradigm_name, r, ".nii.gz"))
		##cat("Searching for file: ", expectedNIfTI, "\n")
                ##if (!file.exists(expectedNIfTI)) {
                ##    ##Check for existence of at least one matching DICOM file in folder (in case DICOM->NIfTI hasn't run yet)
                ##    ndicoms <- list.files(path=file.path(outdir, paste0(paradigm_name, r)), pattern=functional_dicompattern, full.names = TRUE)
                ##    if (length(ndicoms==0L)) {
                ##        message("Cannot find matching DICOMs in directory", 
                ##    }

                ##add raw DICOM directory to copy queue
                ##dir.create(rundir) #create empty run directory for now
                functional_src_queue <- c(functional_src_queue, funcdirs[r])
                functional_dest_queue <- c(functional_dest_queue, rundir)
            }
        }

        if (detect_refimg) {
            refimgs <- d #pass forward subject's raw directory to preprocessFunctional to have refimg detected
        } else  {
            refimgs <- NA #need to handle Prisma CMRR MB data here where reference images are placed in separate directory
            ##because of the unsophisticated cp -rp approach for dicoms, we cannot do the dir.create step above and then
            ##list.dirs below. This works in the MB case because of the more careful checks on number of runs etc.
        }
        
        all_funcrun_dirs[[d]] <- data.frame(funcdir=rundirs, refimgs=refimgs, magdir=magdir, phasedir=phasedir, mpragedir=mpragedir, stringsAsFactors=FALSE)

    }
    
}

if (useOfflineMB) {    
    message("Copy destination queue")
    print(mb_dest_queue)

    ##copy any needed MB reconstructed NIfTIs into place
    ##for now, arbitrarily copy 12 at a time for a reasonable level of disk I/O
    if (length(mb_src_queue) > 0L) {
        registerDoMC(12) #setup number of jobs to fork
        message("Copying MB reconstructed files into place.")
        print(data.frame(src=mb_src_queue, dest=mb_dest_queue), row.names=FALSE)
        f <- foreach(fnum=1:length(mb_src_queue), .inorder=FALSE) %dopar% {
            ##use 3dcopy to copy dataset as .nii.gz
            system(paste0("3dcopy \"", mb_src_queue[fnum], "\" \"", mb_dest_queue[fnum], "\""), wait=TRUE)     
        }
    }
} else {
    if (length(functional_src_queue) > 0L) {
        registerDoMC(12)
        message("Copying raw DICOM folders into place")
        print(data.frame(src=functional_src_queue, dest=functional_dest_queue), row.names=FALSE)
        f <- foreach(fnum=1:length(functional_src_queue), .inorder=FALSE) %dopar% {
            system(paste0("cp -Rp \"", functional_src_queue[fnum], "\" \"", functional_dest_queue[fnum], "\""), wait=TRUE)     
        }
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

    if (useOfflineMB) {
        funcpart <- paste("-4d", Sys.glob(paste0(paradigm_name, "*.nii.gz")))
    } else {
        funcpart <- paste0("-dicom \"", functional_dicompattern, "\" -delete_dicom archive -output_basename ", basename(cd$funcdir)) #assuming archive here
    }
    
    mpragepart <- paste("-mprage_bet", file.path(cd$mpragedir, "mprage_bet.nii.gz"), "-warpcoef", file.path(cd$mpragedir, paste0("mprage_warpcoef", gradunwarpsuffix, ".nii.gz")))
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
