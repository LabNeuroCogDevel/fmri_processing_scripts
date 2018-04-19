#!/usr/bin/env Rscript
#This is a script for automated processing of functional MRI data and their corresponding structural scans.
#It expects to find several key configuration parameters in the system environment at the time of execution.
#These are typically handled upstream of the script by autopreproc, which sources a cfg file to initialize these variables.
#The basic structure is that files are copied from a raw source location to a processed destination location.
#Strutural scans are then processed using preprocessMprage and functional scans are then processed by preprocessFunctional.
#The script uses the foreach/dopar approach with doMC as the backend to make processing embarrassingly parallel.

#The only parameter expected on the command line is the number of jobs to run in parallel, 
#and if not specified, the script defaults to 8.

#read in command line arguments.
args <- commandArgs(trailingOnly = FALSE)

scriptpath <- dirname(sub("--file=", "", grep("--file=", args, fixed=TRUE, value=TRUE), fixed=TRUE))
argpos <- grep("--args", args, fixed=TRUE)
if (length(argpos) > 0L) { args <- args[(argpos+1):length(args)] } else { args <- c() }

#contains exec_pbs_array and list.dirs
source(normalizePath(file.path(scriptpath, "..", "R_helper_functions.R")))

options(width=200)
execdir <- getwd()
#location of raw MR data
goto=Sys.getenv("loc_mrraw_root")
if (! file.exists(goto)) { stop("Cannot find directory: ", goto) }
setwd(goto)
basedir <- getwd() #root directory for processing

njobs <- Sys.getenv("njobs") #number of parallel jobs to run
if (njobs != "") {
  njobs <- as.numeric(njobs)
} else if (length(args) > 0L) {
  njobs <- as.numeric(args[1L])
} else {
  njobs <- 8
}

cat("Maximum number of parallel jobs to execute simultaneously: ", njobs, "\n")

#load required libraries
library(foreach)
library(doMC)
library(iterators)

#pull in cfg environment variables from bash script
mprage_dirpattern = Sys.getenv("mprage_dirpattern") #wildcard pattern defining names of relevant structural scans
mprage_dicompattern = Sys.getenv("mprage_dicompattern")
functional_dirpattern = strsplit(Sys.getenv("functional_dirpattern"), ",")[[1L]]
functional_dicompattern = strsplit(Sys.getenv("functional_dicompattern"), ",")[[1L]]
if (identical(functional_dicompattern, character(0))) { functional_dicompattern = "MR*" }

preprocessed_dirname = Sys.getenv("preprocessed_dirname") #name of subdirectory output for each processed fMRI scan
paradigm_name = strsplit(Sys.getenv("paradigm_name"), ",")[[1L]] #name of paradigm used as a prefix for processed run directories
n_expected_funcruns = strsplit(Sys.getenv("n_expected_funcruns"), ",")[[1]] #number of runs per subject of the task
preproc_call = Sys.getenv("preproc_call") #parameters passed forward to preprocessFunctional
preprocessMprage_call = Sys.getenv("preprocessMprage_call") #parameters passed forward to preprocessMprage
MB_src = Sys.getenv("loc_mb_root") #Name of directory containing offline-reconstructed fMRI data (only relevant for Tae Kim sequence Pittburgh data)
mb_filepattern = Sys.getenv("mb_filepattern") #Wildcard pattern of MB reconstructed data within MB_src
useOfflineMB = ifelse(nchar(MB_src) > 0, TRUE, FALSE) #whether to use offline-reconstructed hdr/img files as preprocessing starting point
proc_freesurfer = as.numeric(Sys.getenv("proc_freesurfer")) #whether to run the structural scan through FreeSurferPipeline after preprocessMprage
preproc_resume = as.numeric(Sys.getenv("preproc_resume"))
if (is.na(preproc_resume)) { preproc_resume <- FALSE } else if (preproc_resume==0) { preproc_resume <- FALSE } else if (preproc_resume==1) { preproc_resume <- TRUE }

#handle situation where we have multiple paradigms
if (length(functional_dirpattern) != length(paradigm_name)) { stop("Length of functional_dirpattern does not match length of paradigm_name") }
if (length(paradigm_name) > 1L) {
  if (length(n_expected_funcruns) == 1L) { n_expected_funcruns <- rep(n_expected_funcruns, length(paradigm_name)) } #replicate number of expected runs per paradigm
  if (length(functional_dicompattern) == 1L) { functional_dicompattern <- rep(functional_dicompattern, length(paradigm_name)) } #replicate dicom pattern expectation per paradigm  
}

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

#whether to use a PBS job array rather than running jobs directly through R
use_job_array = as.numeric(Sys.getenv("use_job_array"))
if (is.na(use_job_array)) {
  use_job_array <- FALSE
} else if (use_job_array == 1) {
  use_job_array <- TRUE
  cat("Using PBS job array approach to parallel execution\n\n")
} else {
  use_job_array <- FALSE #should I trap other possibilities here?    
}

use_moab <- as.numeric(Sys.getenv("use_moab")) #default is to use torque dependencies with -W. But can use moab with -l instead
if (is.na(use_moab)) {
  use_moab <- FALSE
} else if (use_moab == 1) {
  use_moab <- TRUE
  cat("Using moab for PBS job dependency handling\n")
} else {
  use_moab <- FALSE #should I trap other possibilities here?    
}

if (use_moab) { use_job_array <- TRUE } #Moab implies a job array

use_massive_qsub = as.numeric(Sys.getenv("use_massive_qsub"))
if (is.na(use_massive_qsub)) {
  use_massive_qsub <- FALSE
} else if (use_massive_qsub == 1) {
  use_massive_qsub <- TRUE
  cat("Using massive single-job qsub approach to parallel execution\n\n")
} else {
  use_massive_qsub <- FALSE #should I trap other possibilities here?    
}

#unified flag to denote whether to use qsub approach
if (use_job_array || use_moab || use_massive_qsub) {
  asynchronous_processing <- TRUE
} else {
  asynchronous_processing <- FALSE
}

job_array_preamble <- Sys.getenv("job_array_preamble")
if (job_array_preamble=="") {
  job_array_preamble <- c(
    "#!/usr/bin/env sh",
  "",
  "#PBS -A mnh5174_a_g_hc_default",
  "#PBS -j oe",
  "#PBS -W group_list=mnh5174_collab", #default to having correct group
  "#PBS -m n" #do not send emails related to job arrays
  #"#PBS -M michael.hallquist@psu.edu", #job arrays generate one email per worker!! Too much pain
  )
}

#setup default wall times for different steps
if (asynchronous_processing) {
  mprage_walltime <- Sys.getenv("mprage_walltime")
  if (mprage_walltime == "") { mprage_walltime <- "4:00:00" } # 4-hour max estimate for a single subject mprage to process
  freesurfer_walltime <- Sys.getenv("freesurfer_walltime")
  if (freesurfer_walltime == "") { freesurfer_walltime <- "54:00:00" } # 54-hour max estimate for a single subject freesurfer to process
  functional_walltime <- Sys.getenv("functional_walltime")
  if (functional_walltime == "") { functional_walltime <- "40:00:00" } # 40-hour max estimate for a single subject functional to process  
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

if (preprocessMprage_call == "") { preprocessMprage_call = paste0("-delete_dicom archive -template_brain MNI_2mm") }

#add dicom pattern into the mix
preprocessMprage_call <- paste0(preprocessMprage_call, " -dicom \"", mprage_dicompattern, "\"")
usegradunwarp=grepl("-grad_unwarp\\s+", preprocessMprage_call, perl=TRUE)
gradunwarpsuffix=""
if (usegradunwarp) {
  message("Using structural -> MNI warp coefficients that include gradient undistortion: _withgdc.")
  message("Also: assuming that all images provided to preprocessFunctional (incl. mprage and fieldmap) are not corrected for gradient distortion")
  gradunwarpsuffix <- "_withgdc"
} 

#optional config settings
loc_mrproc_root = Sys.getenv("loc_mrproc_root")
gre_fieldmap_dirpattern = Sys.getenv("gre_fieldmap_dirpattern")
fieldmap_cfg = Sys.getenv("fieldmap_cfg")
se_phasepos_dirpattern = Sys.getenv("se_phasepos_dirpattern")
se_phaseneg_dirpattern = Sys.getenv("se_phaseneg_dirpattern")
se_phasepos_dicompattern = Sys.getenv("se_phasepos_dicompattern")
se_phaseneg_dicompattern = Sys.getenv("se_phaseneg_dicompattern")
useGREFieldmap = ifelse(nchar(gre_fieldmap_dirpattern) > 0, TRUE, FALSE) #whether to include GRE fieldmaps in processing
useSEFieldmap = ifelse(nchar(se_phasepos_dirpattern) > 0, TRUE, FALSE) #whether to include SE fieldmaps in processing

#setup location for script outputs
if (asynchronous_processing) {
  registerDoSEQ() #force sequential
  scratchdir <- paste0("/gpfs/scratch/", system("whoami", intern=TRUE))
  qsubdir <- tempfile(pattern="preprocessAll_", tmpdir=ifelse(dir.exists(scratchdir), scratchdir, execdir))
  dir.create(qsubdir, showWarnings=FALSE)

  if (use_massive_qsub) {
    #under massive individual qsub, each worker script is a qsub job itself
    #but to keep the paradigm consistent (the exec_pbs_array function handles PBS directives),
    #we just want the ni_path setup. The preamble will be prepended to each at runtime.
    preproc_one <- c("source /gpfs/group/mnh5174/default/lab_resources/ni_path.bash #setup environment")
  } else {
    preproc_one <- c(
      "#!/bin/bash",
      "source /gpfs/group/mnh5174/default/lab_resources/ni_path.bash #setup environment"
    )
  }
} else {
  registerDoMC(njobs) #setup number of jobs to fork
}

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
cat("  Name of paradigm folder:", paste(paradigm_name, collapse=","), ", expected runs:", paste(n_expected_funcruns, collapse=","), "\n")
cat("  Prefer preprocessFunctional -resume for directories in process: ", as.character(preproc_resume), "\n")

if (useOfflineMB) {
  cat("  Using offline-reconstructed multiband data (Tae Kim Pittsburgh sequence)\n")
  cat("  Expected name of offline-reconstructed multiband files:", mb_filepattern, "\n")
  cat("  Directory containing MB-reconstructed files:", MB_src, "\n")
}
if (useGREFieldmap) {
  cat("  Using GRE fieldmap correction\n")
  cat("  Expected name of GRE fieldmap source directories:", gre_fieldmap_dirpattern, "\n")
  cat("  Fieldmap configuration file:", fieldmap_cfg, "\n")
}
if (useSEFieldmap) {
  cat("  Using SE fieldmap correction via TOPUP\n")
  cat("  Expected name of SE positive fieldmap source directories:", se_phasepos_dirpattern, "\n")
  cat("  Expected name of SE negative fieldmap source directories:", se_phaseneg_dirpattern, "\n")
}
if (use_job_array) {
  cat("  Using a PBS array approach to queue preprocessing\n")
  cat("  Directory for PBS job array files:", qsubdir, "\n")
  cat("  Maximum number of concurrent jobs:", njobs, "\n")
  cat("  Using this scheduler for handling arrays:", ifelse(use_moab, "moab", "torque"), "\n")
  cat("  Walltime for single preprocessMprage:", mprage_walltime, "\n")
  if (proc_freesurfer) { cat("  Walltime for freesurfer:", freesurfer_walltime, "\n") }
  cat("  Walltime for single functional:", functional_walltime, "\n")
  cat("  Basic setup for qsub scripts:\n")
  cat(job_array_preamble, sep="\n")
}
if (use_massive_qsub) {
  cat("  Using a massive individual qsub approach to queue preprocessing\n")
  cat("  Directory for PBS job files:", qsubdir, "\n")
  cat("  Walltime for single preprocessMprage:", mprage_walltime, "\n")
  if (proc_freesurfer) { cat("  Walltime for freesurfer:", freesurfer_walltime, "\n") }
  cat("  Walltime for single functional:", functional_walltime, "\n")
  cat("  Basic setup for qsub scripts:\n")
  cat(job_array_preamble, sep="\n")  
}
cat("--------\n\n")

##handle all mprage directories

##find original mprage directories to rename
##mprage_dirs <- list.dirs(pattern=mprage_dirpattern)

##Much faster on *nix-friendly systems than above because can control search depth
##Note that the depth of 2 assumes a structure such as Project_Dir/SubjectID/mprage_dir where each subject has a single directory
mprage_dirs <- system(paste0("find $PWD -mindepth 2 -maxdepth 2 -iname \"", mprage_dirpattern, "\" -type d"), intern=TRUE)
subids <- basename(dirname(mprage_dirs)) #subject ids are used for checking for multiple mprage scans per subject
mprage_dirs_byid <- split(mprage_dirs, subids)
mprage_dirs <- unlist(lapply(mprage_dirs_byid, function(subject) {
  #making assumptions that series numbers fall either first or last and that the last series number should be preferred
  if (length(subject) > 1L) {
    message("Multiple mprage folders identified for a single subject. Will prefer the one with the highest series number")
    print(subject, row.names=FALSE)
    have_leading_digits <- grepl("^\\d+.*", subject, perl=TRUE)
    have_trailing_digits <- grepl(".*[^\\d]+\\d+$", subject, perl=TRUE)
    if (all(have_trailing_digits)) {
      #require at least one preceding non-digit character to avoid .* greedy matching all but last digit
      sernum <- as.numeric(sub(".*[^\\d]+(\\d+)$", "\\1", subject, perl=TRUE))
    } else if (all(have_leading_digits)) {
      sernum <- as.numeric(sub("^(\\d+).*", "\\1", subject, perl=TRUE))
    } else { stop("Unable to parse series numbers from inputs: ", subject) }

    return(subject[which.max(sernum)])
  } else { return(subject) }
}))

##find all renamed mprage directories for processing
##use beginning and end of line markers to force exact match
##use getwd to force absolute path since we setwd below
##mprage_dirs <- list.dirs(pattern="^mprage$", path=getwd())

##faster than above
##mprage_dirs <- system("find $PWD -mindepth 2 -maxdepth 2 -type d -iname mprage", intern=TRUE)

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
  } else if (!file.exists(file.path(outdir, "mprage")) ||   #output directory exists, but mprage subdirectory does not
               !file.exists(file.path(outdir, "mprage", ".preprocessmprage_complete"))) {   #mprage subdirectory exists, but complete file does not
    mprage_toprocess <- c(mprage_toprocess, d)
  }
}

mprage_jobid <- NULL #for job array tracking of preprocessMprage
mprage_copy_jobid <- NULL #for job array tracking of mprage file copy
if (length(mprage_toprocess) > 0L) {
  cat("About to process the following mprage directories:\n")
  print(mprage_toprocess)

  #copy mprage files for processing
  if (asynchronous_processing) {
    mprage_dest_queue <- file.path(loc_mrproc_root, basename(dirname(mprage_toprocess)), "mprage") #assume that output structure is MR_Proc/<SUBID>/mprage
    have_dest <- dir.exists(mprage_dest_queue)
    mprage_src_queue <- mprage_toprocess[!have_dest] #only copy directories that don't already exist
    mprage_dest_queue <- mprage_dest_queue[!have_dest]
    mprage_copy_jobid <- exec_pbs_iojob(mprage_src_queue, mprage_dest_queue, cpcmd="cp -Rp", njobs=24, qsubdir=qsubdir, jobname="qsub_mpragecopy")
  } else {
    for (i in 1:length(mprage_toprocess)) {
      d <- mprage_toprocess[i]
      subid <- basename(dirname(d))
      outdir <- file.path(loc_mrproc_root, subid)
      if (!file.exists(file.path(outdir, "mprage"))) { system(paste("cp -Rp", d, file.path(outdir, "mprage"))) } #copy untouched mprage to processed directory
    }
  }
  
  #preprocess mprage directories
  f <- foreach(i=1:length(mprage_toprocess), .inorder=FALSE) %dopar% {
    d <- mprage_toprocess[i]
    subid <- basename(dirname(d))
    mpragedir <- file.path(loc_mrproc_root, subid, "mprage")

    #call preprocessmprage
    if (dir.exists(mpragedir) && file.exists(file.path(mpragedir, ".preprocessmprage_complete"))) {
      #this would only fire if the _complete file is created after the initial queue setup (very unlikely)
      return("complete")
    } else {
      if (dir.exists(mpragedir) && file.exists(file.path(mpragedir, "mprage.nii.gz"))) {
        preprocessMprage_call = sub("-dicom\\s+\\S+\\s+", "", preprocessMprage_call, perl=TRUE) #strip out call to dicom
        preprocessMprage_call <- paste(preprocessMprage_call, "-nifti mprage.nii.gz")
      }

      if (file.exists("need_analyze")) { unlink("need_analyze") } #remove dummy file
      if (file.exists("analyze")) { unlink("analyze") } #remove dummy file

      if (asynchronous_processing) {
        #create preprocessing script for the ith dataset
        output_script <- c(preproc_one,
                           paste("cd", mpragedir),
                           paste("preprocessMprage", preprocessMprage_call, ">preprocessMprage_stdout 2>preprocessMprage_stderr"))
        cat(output_script, sep="\n", file=file.path(qsubdir, paste0("qsub_one_preprocessMprage_", i)))
      } else {
        setwd(mpragedir)
        ret_code <- system2("preprocessMprage", preprocessMprage_call, stderr="preprocessMprage_stderr", stdout="preprocessMprage_stdout")
        if (ret_code != 0) { message("preprocessMprage failed in directory: ", mpragedir) }
        #echo current date/time to .preprocessmprage_complete to denote completed preprocessing
        #NB: newer versions of preprocessMprage (Nov2016 and beyond) handle this internally
        if (!file.exists(".preprocessmprage_complete")) {
          sink(".preprocessmprage_complete"); cat(as.character(Sys.time())); sink()
        }
      }
    }
    return(d)
  }

  if (asynchronous_processing) {
    #execute mprage array job
    mprage_jobid <- exec_pbs_array(max_concurrent_jobs=njobs, njobstorun=length(mprage_toprocess), jobprefix="qsub_one_preprocessMprage_", allscript="qsub_all_mprage.bash",
      qsubdir=qsubdir, job_array_preamble=job_array_preamble, walltime=mprage_walltime, waitfor=mprage_copy_jobid,
      use_moab=use_moab, use_massive_qsub=use_massive_qsub)
  }
}

#handle FreeSurfer preprocessing
freesurfer_jobid <- NULL
if (proc_freesurfer) {
  #look for which subjects are already complete
  fs_toprocess <- c()
  ids_toproc <- c()
  for (d in mprage_dirs) {
    subid <- basename(dirname(d))
    outdir <- file.path(loc_mrproc_root, subid)
    
    if (!asynchronous_processing && !file.exists(file.path(outdir, "mprage"))) {
      message("Cannot locate processed mprage data for: ", outdir)
    } else if (!asynchronous_processing && !file.exists(file.path(outdir, "mprage", ".preprocessmprage_complete"))) {
      message("Cannot locate .preprocessmprage_complete in: ", outdir)
    } else if (file.exists(file.path(fs_subjects_dir, paste0(freesurfer_id_prefix, subid)))) {
      message("Skipping FreeSurfer pipeline for subject: ", subid)
    } else {
      fs_toprocess <- c(fs_toprocess, file.path(outdir, "mprage"))
      ids_toproc <- c(ids_toproc, paste0(freesurfer_id_prefix, subid))
    }
  }

  if (length(fs_toprocess) > 0) {
    message("About to run FreeSurfer pipeline on the following datasets:")
    cat(fs_toprocess, sep="\n")
    
    f <- foreach(d=1:length(fs_toprocess), .inorder=FALSE) %dopar% {

      #use the gradient distortion-corrected files if available
      if (asynchronous_processing) {
        #create preprocessing script for the ith dataset
        output_script <- c(preproc_one,
                           paste0("[ ! -d \"", fs_toprocess[d], "\" ] && { echo \"Cannot find directory: ", fs_toprocess[d], ". Aborting.\"; exit 0; }"),
                           paste0("[ ! -r \"", file.path(fs_toprocess[d], ".preprocessmprage_complete"),
                                  "\" ] && { echo \"Cannot find .preprocessmprage_complete in: ", fs_toprocess[d], ". Aborting.\"; exit 0; }"),
                           paste("cd", fs_toprocess[d]),
                           "[ -r \"mprage_biascorr_postgdc.nii.gz\" ] && t1=mprage_biascorr_postgdc.nii.gz || t1=mprage_biascorr.nii.gz",
                           "[ -r \"mprage_bet_postgdc.nii.gz\" ] && t1brain=mprage_bet_postgdc.nii.gz || t1brain=mprage_bet.nii.gz",
                           paste("FreeSurferPipeline -subject", ids_toproc[d], "-subjectDir", fs_subjects_dir, "-T1 $t1 -T1brain $t1brain >FreeSurferPipeline_stdout 2>FreeSurferPipeline_stderr"))
        cat(output_script, sep="\n", file=file.path(qsubdir, paste0("qsub_one_FreeSurferPipeline_", d)))
      } else {
        setwd(fs_toprocess[d])
        t1 <- ifelse(file.exists("mprage_biascorr_postgdc.nii.gz"), "mprage_biascorr_postgdc.nii.gz", "mprage_biascorr.nii.gz")
        t1brain <- ifelse(file.exists("mprage_bet_postgdc.nii.gz"), "mprage_bet_postgdc.nii.gz", "mprage_bet.nii.gz")
        freesurfer_call <- paste0("-T1 ", t1, " -T1brain ", t1brain, " -subject ", ids_toproc[d], " -subjectDir ", fs_subjects_dir)
        ret_code <- system2("FreeSurferPipeline", args=freesurfer_call,
                            stderr="FreeSurferPipeline_stderr", stdout="FreeSurferPipeline_stdout")
        if (ret_code != 0) { message("FreeSurferPipeline failed in directory: ", fs_toprocess[d]) }
      }
    }

    if (asynchronous_processing) {
      #execute freesurfer array job
      freesurfer_jobid <- exec_pbs_array(max_concurrent_jobs=njobs, njobstorun=length(fs_toprocess), qsubdir=qsubdir,
                                         jobprefix="qsub_one_FreeSurferPipeline_", allscript="qsub_all_freesurfer.bash",
                                         waitfor=mprage_jobid, job_array_preamble=job_array_preamble, walltime=freesurfer_walltime,
                                         use_moab=use_moab, use_massive_qsub=use_massive_qsub)
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
  if (useGREFieldmap) {
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
    } else {
      message("In ", d, ", number of fieldmap dirs is not 2: ", paste0(fmdirs, collapse=", "))
      message("Skipping subject: ", d)
      next
    }
  }

  posdir <- negdir <- NA_character_ #reduce risk of accidentally carrying over fieldmap from one subject to next in loop
  if (useSEFieldmap) {
    fmdirspos <- sort(normalizePath(Sys.glob(file.path(d, se_phasepos_dirpattern))))
    fmdirsneg <- sort(normalizePath(Sys.glob(file.path(d, se_phaseneg_dirpattern))))
    if (length(fmdirspos)==1L && length(fmdirsneg)==1L) {
      apply_fieldmap <- TRUE
      posdir <- file.path(loc_mrproc_root, subid, "positive_spinecho")
      negdir <- file.path(loc_mrproc_root, subid, "negative_spinecho")
      if (!file.exists(posdir)) { system(paste("cp -Rp", fmdirspos[1], posdir)) }
      if (!file.exists(negdir)) { system(paste("cp -Rp", fmdirsneg[1], negdir)) }
      posdir <- file.path(posdir, se_phasepos_dicompattern)
      negdir <- file.path(negdir, se_phaseneg_dicompattern)
    } else {
      message("In ", d, ", number of SE dirs is not 2: ", paste0(fmdirspos, fmdirsneg, collapse=", "))
      message("Skipping subject: ", d)
      next
    }
  }
  
  mpragedir <- file.path(loc_mrproc_root, subid, "mprage")
  #Only validate mprage directory structure if we are not using job arrays.
  #For a job array, the mprage folders/files may not be in place yet since this script functions more for setup than computation
  if (!asynchronous_processing) { 
    if (file.exists(mpragedir)) {
      if (! (file.exists(file.path(mpragedir, paste0("mprage_warpcoef", gradunwarpsuffix, ".nii.gz"))) && file.exists(file.path(mpragedir, "mprage_bet.nii.gz")) ) ) {
        message("Unable to locate required mprage files in dir: ", mpragedir)
        message("Skipping subject: ", d)
        next
      }
    } else {
      message("Unable to locate mprage directory: ", mpragedir)
      message("Skipping subject: ", d)
      next
    }
  }
    
  ##create paradigm_run1-paradigm_run<N> folder structure and copy raw data
  if (!file.exists(outdir)) { #create preprocessed root folder if absent
    dir.create(outdir, showWarnings=FALSE, recursive=TRUE)
  } else {
    ##preprocessed folder exists, check for .preprocessfunctional_complete files for all paradigms
    paradigms_complete <- 0
    for (p in 1:length(paradigm_name)) {      
      extant_funcrundirs <- list.dirs(path=outdir, pattern=paste0("^", paradigm_name[p],"[0-9]+$"), full.names=TRUE, recursive=FALSE)
      if (length(extant_funcrundirs) > 0L &&
            length(extant_funcrundirs) >= n_expected_funcruns[p] &&
            all(sapply(extant_funcrundirs, function(x) { file.exists(file.path(x, ".preprocessfunctional_complete")) }))) {
        cat("   preprocessing already complete for all functional run directories for paradigm:", paradigm_name[p], "in: ", outdir, "\n\n")
        paradigms_complete <- paradigms_complete + 1
      }
    }
    if (paradigms_complete == length(paradigm_name)) {
      cat("   preprocessing already complete for all paradigm run directories in: ", outdir, "\n\n")
      next
    }
  }

  #Handle the use of offline-reconstructed hdr/img files as the starting point of preprocessFunctional (Tae Kim Pittsburgh data)
  if (useOfflineMB) {
    ##NB. Offline MB processing does not currently support multi-paradigm execution using the comma-separated argument approach
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

    subjdf <- c()
    ##loop over files and setup run directories in preprocessed_dirname
    for (m in 1:length(mbfiles)) {
      ##only copy data if folder does not exist
      funcdir <- file.path(outdir, paste0(paradigm_name, runnums[m]))
      funcnifti <- paste0(paradigm_name, runnums[m], ".nii.gz")
      expectedNIfTI <- file.path(funcdir, funcnifti)
      
      if (!file.exists(funcdir)) {
        dir.create(funcdir)
        
        ##Check for existence of unprocessed MB reconstructed NIfTI. If doesn't exist, add to copy queue

        cat("Searching for file: ", expectedNIfTI, "\n")
        if (!file.exists(expectedNIfTI)) {
          mb_src_queue <- c(mb_src_queue, mbfiles[m])
          mb_dest_queue <- c(mb_dest_queue, expectedNIfTI)
        }
      }

      subjdf <- rbind(subjdf, data.frame(funcdir=funcdir, funcnifti=funcnifti, refimgs=refimgs[m], magdir=magdir, phasedir=phasedir, posdir=posdir, negdir=negdir, mpragedir=mpragedir, stringsAsFactors=FALSE))
    }

    ##add all functional runs, along with mprage and fmap info, as a data.frame to the list
    all_funcrun_dirs[[d]] <- subjdf

  } else {
    ##check for existing run directories and setup copy queue as needed
    for (p in 1:length(paradigm_name)) {
      
      funcdirs <- sort(normalizePath(Sys.glob(file.path(d, functional_dirpattern[p]))))

      if (length(funcdirs) == 0L) {
        message("Cannot find any functional runs directories in ", d, " for pattern ", functional_dirpattern[p])
        message("Skipping participant for now")
        next
      } else if (length(funcdirs) != n_expected_funcruns[p]) {
        message("Cannot find the expected number of functional run directories,", n_expected_funcruns[p], "in", d, " for pattern ", functional_dirpattern[p])
        message("Skipping participant for now")
        next
      }

      if (detect_refimg) {
        refimgs <- d #pass forward subject's raw directory to preprocessFunctional to have refimg detected
      } else  {
        refimgs <- NA #need to handle Prisma CMRR MB data here where reference images are placed in separate directory
        ##because of the unsophisticated cp -rp approach for dicoms, we cannot do the dir.create step above and then
        ##list.dirs below. This works in the MB case because of the more careful checks on number of runs etc.
      }
      
      subjdf <- c()
      for (r in 1:n_expected_funcruns[p]) {

        funcdir <- file.path(outdir, paste0(paradigm_name[p], r))
        funcnifti <- paste0(paradigm_name[p], r, ".nii.gz")
        expectedNIfTI <- file.path(funcdir, funcnifti)
        
        if (!file.exists(funcdir)) {
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
          ##dir.create(funcdir) #create empty run directory for now
          functional_src_queue <- c(functional_src_queue, funcdirs[r])
          functional_dest_queue <- c(functional_dest_queue, funcdir)
        }

        subjdf <- rbind(subjdf, data.frame(funcdir=funcdir, funcnifti=funcnifti, funcdcm=functional_dicompattern[p], refimgs=refimgs, magdir=magdir, phasedir=phasedir, posdir=posdir, negdir=negdir, mpragedir=mpragedir, stringsAsFactors=FALSE))
      }
      
      all_funcrun_dirs[[ paste0(d, "_", paradigm_name[p]) ]] <- subjdf
    }
  }
}

#handle functional file i/o before initiating preprocessFunctional
queue_copy_jobid <- NULL
if (useOfflineMB) {
  ##copy any needed MB reconstructed NIfTIs into place

  if (length(mb_src_queue) > 0L) {
    message("Copying MB reconstructed files into place.")
    print(data.frame(src=mb_src_queue, dest=mb_dest_queue), row.names=FALSE)

    if (asynchronous_processing) {
      queue_copy_jobid <- exec_pbs_iojob(mb_src_queue, mb_dest_queue, cpcmd="3dcopy", njobs=24, qsubdir=qsubdir)
    } else {
      ##for now, arbitrarily copy 12 at a time for a reasonable level of disk I/O
      registerDoMC(12) #setup number of jobs to fork
      f <- foreach(fnum=1:length(mb_src_queue), .inorder=FALSE) %dopar% {
        ##use 3dcopy to copy dataset as .nii.gz
        system(paste0("3dcopy \"", mb_src_queue[fnum], "\" \"", mb_dest_queue[fnum], "\""), wait=TRUE)     
      }
    }
  }
} else {
  if (length(functional_src_queue) > 0L) {
    message("Copying raw DICOM folders into place")
    print(data.frame(src=functional_src_queue, dest=functional_dest_queue), row.names=FALSE)

    if (asynchronous_processing) {
      queue_copy_jobid <- exec_pbs_iojob(functional_src_queue, functional_dest_queue, cpcmd="cp -Rp", njobs=24, qsubdir=qsubdir)
    } else {
      registerDoMC(12)
      f <- foreach(fnum=1:length(functional_src_queue), .inorder=FALSE) %dopar% {
        system(paste0("cp -Rp \"", functional_src_queue[fnum], "\" \"", functional_dest_queue[fnum], "\""), wait=TRUE)     
      }
    }
  }
}

#rbind data frame together
all_funcrun_dirs <- do.call(rbind, all_funcrun_dirs)
row.names(all_funcrun_dirs) <- NULL

#re-register parallel backend since it was set to 12 just above (ideally, the copying should be outsourced to a function)
if (asynchronous_processing) {
  registerDoSEQ() #force sequential
} else {
  registerDoMC(njobs) #setup number of jobs to fork
}

if (!is.null(all_funcrun_dirs) && nrow(all_funcrun_dirs) > 0L) {
  #loop over directories to process
  ##for (curdir in all_funcrun_dirs) {
  f <- foreach(i=1:nrow(all_funcrun_dirs), .inorder=FALSE) %dopar% {
    curdir <- all_funcrun_dirs[i,]
    
    resumepart <- funcpart <- mpragepart <- fmpart <- separt <- refimgpart <- ""
    if (dir.exists(curdir$funcdir) && file.exists(file.path(curdir$funcdir, ".preprocessfunctional_incomplete")) && preproc_resume) {
      resumepart <- "-resume"
      preproc_call <- "" #clear other settings
    } else {
      if (useOfflineMB) {
        funcpart <- paste("-4d", curdir$funcnifti)
      } else {
        funcpart <- paste0("-dicom \"", curdir$funcdcm, "\" -delete_dicom archive -output_basename ", basename(curdir$funcdir)) #assuming archive here
      }
      
      mpragepart <- paste("-mprage_bet", file.path(curdir$mpragedir, "mprage_bet.nii.gz"), "-warpcoef", file.path(curdir$mpragedir, paste0("mprage_warpcoef", gradunwarpsuffix, ".nii.gz")))

      if (!is.na(curdir$magdir)) { fmpart <- paste0("-fm_phase \"", curdir$phasedir, "\" -fm_magnitude \"", curdir$magdir, "\" -fm_cfg ", fieldmap_cfg) }

      #-epi_pedir and -epi_echospacing need to be specified in preproc_call of config file
      if (!is.na(curdir$posdir)) { separt <- paste0("-se_phasepos \"", curdir$posdir, "\" -se_phaseneg \"", curdir$negdir, "\"") }
      
      if (!is.na(curdir$refimgs)) { refimgpart <- paste0("-func_refimg \"", curdir$refimgs, "\" ") }
    }

    ##run preprocessFunctional
    args <- paste(resumepart, funcpart, mpragepart, fmpart, separt, refimgpart, preproc_call)

    if (asynchronous_processing) {
      output_script <- c(preproc_one,
                         paste("cd", curdir$funcdir),
                         paste("preprocessFunctional", args, ">preprocessFunctional_stdout 2>preprocessFunctional_stderr"))
      cat(output_script, sep="\n", file=file.path(qsubdir, paste0("qsub_one_preprocessFunctional_", i)))
    } else {
      setwd(curdir$funcdir)
      ret_code <- system2("preprocessFunctional", args, stderr="preprocessFunctional_stderr", stdout="preprocessFunctional_stdout")
      if (ret_code != 0) { message("preprocessFunctional failed in directory: ", curdir$funcdir) }
    }
  }

  if (asynchronous_processing) {
    save(all_funcrun_dirs, file=file.path(qsubdir, "funcdata_toprocess.RData"))
    #execute functional array job
    functional_jobid <- exec_pbs_array(max_concurrent_jobs=njobs, njobstorun=nrow(all_funcrun_dirs), jobprefix="qsub_one_preprocessFunctional_", qsubdir=qsubdir,
      allscript="qsub_all_functional.bash", waitfor=c(queue_copy_jobid, mprage_jobid), job_array_preamble=job_array_preamble, walltime=functional_walltime,
      use_moab=use_moab, use_massive_qsub=use_massive_qsub)
  }
}
