runAFNICommand <- function(args, afnidir=NULL, stdout=NULL, stderr=NULL, ...) {

  ##look for AFNIDIR in system environment if not passed in
  if (is.null(afnidir)) {
    env <- system("env", intern=TRUE)
    if (length(afnidir <- grep("^AFNIDIR=", env, value=TRUE)) > 0L) {
      afnidir <- sub("^AFNIDIR=", "", afnidir)
    } else if (length(afniloc <- suppressWarnings(system("which afni", intern=TRUE))) > 0L) {
      afnidir <- dirname(afniloc)
    } else {
      warning("AFNIDIR not found in environment. Defaulting to ", paste0(normalizePath("~/"), "/afni"))
      afnidir <- paste0(normalizePath("~/"), "/afni")
    }
  }
  
  Sys.setenv(AFNIDIR=afnidir) #export to R environment
  afnisetup=paste0("AFNIDIR=", afnidir, "; PATH=${AFNIDIR}:${PATH}; DYLD_FALLBACK_LIBRARY_PATH=${AFNIDIR}; ${AFNIDIR}/")
  afnicmd=paste0(afnisetup, args)
  if (!is.null(stdout)) { afnicmd=paste(afnicmd, ">", stdout) }
  if (!is.null(stderr)) { afnicmd=paste(afnicmd, "2>", stderr) }
  cat("AFNI command: ", afnicmd, "\n")
  retcode <- system(afnicmd, ...)
  return(retcode)
}

##function to setup and submit a PBS array job in which a number of (single-thread) individual processes are executed, whilst controlling
##for the total number of concurrent jobs
##https://docs.loni.org/wiki/PBS_Job_Chains_and_Dependencies
exec_pbs_array <- function(max_concurrent_jobs, njobstorun, max_cores_per_node=40,
                           jobprefix="qsub_one_", allscript="qsub_all.bash", qsubdir=tempdir(),
                           job_array_preamble=NULL, waitfor=NULL, walltime="24:00:00") {
  if (is.null(job_array_preamble)) { stop("Require job_array_preamble for exec_pbs_array") }
  array_concurrent_jobs <- min(max_concurrent_jobs, njobstorun) #don't request more than we need
  nnodes <- ceiling(array_concurrent_jobs/max_cores_per_node)
  ppn <- ceiling(array_concurrent_jobs/nnodes)
    
  if (!is.null(waitfor)) {
    #do we need another PBS job to finish successfully before this executes?
    #array have to be handled differently using afterokayarray signal (which indicates that all jobs in array have completed)
    #http://arc-ts.umich.edu/software/torque/pbs-job-dependencies/
    afterok_jobs <- c()
    afterokarray_jobs <- c()
    for (w in waitfor) {
      if (grepl("^\\d+\\[\\].*", w, perl=TRUE)) { #jobid has <numbers>[] form, indicating array
        afterokarray_jobs <- c(afterokarray_jobs, w)
      } else {
        afterok_jobs <- c(afterok_jobs, w)
      }
    }
    waitfor_all <- c()
    if (length(afterok_jobs) > 0L) { waitfor_all <- c(waitfor_all, paste0("afterok:", paste(afterok_jobs, collapse=":"))) }
    if (length(afterokarray_jobs) > 0L) { waitfor_all <- c(waitfor_all, paste0("afterokarray:", paste(afterokarray_jobs, collapse=":"))) }
    waitfor <- paste(waitfor_all, collapse=",") #add a comma between afterok and afterokarray directives, if needed

    job_array_preamble <- c(job_array_preamble, paste0("#PBS -W depend=", waitfor)) #waitfor can be a vector, which is then a colon-separated list of jobs to wait for
  }

  qsub_all <- c(job_array_preamble,
                paste0("#PBS -t 1-", njobstorun, "%", array_concurrent_jobs), #number of total datasets and number of concurrent jobs
                ##paste0("#PBS -l nodes=", nnodes, ":ppn=", ppn, ":himem"), #this is a misunderstanding of the use of job arrays. we need to request resources *per job* as below
                paste0("#PBS -l nodes=1:ppn=1:himem"), #each individual run is a single-threaded job
                paste0("#PBS -l walltime=", walltime), #max time for each job to run
                paste("cd", qsubdir), #cd into the directory with preproc_one scripts
                paste0("bash ", jobprefix, "${PBS_ARRAYID}")
                )

  tosubmit <- file.path(qsubdir, allscript)
  cat(qsub_all, sep="\n", file=tosubmit)
  qsubstdout <- paste0(tools::file_path_sans_ext(tosubmit), "_stdout")
  qsubstderr <- paste0(tools::file_path_sans_ext(tosubmit), "_stderr")
  setwd(qsubdir) #execute qsub from the temporary directory so that output files go there
  jobres=system2("qsub", args=tosubmit, stdout=qsubstdout, stderr=qsubstderr) #submit the preproc_all job and return the jobid
  if (jobres != 0) { stop("qsub submission failed: ", tosubmit) }
  jobid <- scan(file=qsubstdout, what="char", sep="\n", quiet=TRUE)

  return(jobid)
}

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

exec_pbs_iojob <- function(srclist, destlist, cpcmd="cp -Rp", njobs=12, qsubdir=getwd(), walltime="10:00:00", jobname="qsub_iojob") {
  stopifnot(length(srclist)==length(destlist))

  #remove email directives from PBS jobs
  #"#PBS -M michael.hallquist@psu.edu",
  #"#PBS -m abe"

  output_script <- c("#!/usr/bin/env sh",
  "",
  paste0("#PBS -l walltime=", walltime),
  "#PBS -A mnh5174_a_g_hc_default",
  "#PBS -j oe",
  paste0("#PBS -l nodes=1:ppn=",njobs,":himem"),
  "source /gpfs/group/mnh5174/default/lab_resources/ni_path.bash #setup environment",
  paste0("src_queue=(\"", paste(srclist, collapse="\" \""), "\")"),
  "  ",
  paste0("dest_queue=(\"", paste(destlist, collapse="\" \""), "\")"),
  paste0("for ((f=0; f < ", length(srclist), "; f++)); do"),
  "  joblist=($(jobs -p)) #list of running jobs",
  "  ",
  "  #wait here until number of jobs is <= limit",
  paste0("  while (( ${#joblist[*]} >= ", njobs, " ))"),
  "  do",
  "    sleep 1",
  "    joblist=($(jobs -p))",
  "  done",
  "  ",
  paste0(cpcmd, " \"${src_queue[$f]}\" \"${dest_queue[$f]}\" &"),
  "done",
  "wait")
  
  tosubmit <- file.path(qsubdir, jobname)
  cat(output_script, sep="\n", file=tosubmit)
  
  qsubstdout <- paste0(tools::file_path_sans_ext(tosubmit), "_stdout")
  qsubstderr <- paste0(tools::file_path_sans_ext(tosubmit), "_stderr")
  setwd(qsubdir) #execute qsub from the temporary directory so that output files go there
  jobres=system2("qsub", args=tosubmit, stdout=qsubstdout, stderr=qsubstderr) #submit the preproc_all job and return the jobid
  if (jobres != 0) { stop("qsub submission failed: ", tosubmit) }
  jobid <- scan(file=qsubstdout, what="char", sep="\n", quiet=TRUE)

  return(jobid)

}
