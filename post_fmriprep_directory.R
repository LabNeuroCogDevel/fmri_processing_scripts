post_fmriprep_directory <- function(
  dir, subject_regex="sub-.*", bold_regex="sub-.*_task.*desc-preproc_bold\\.nii\\.gz", 
  config_yaml = "post_fmriprep.yaml",
  ncpus=4L, chunksize=1L, subj_min=60, scheduler="slurm") {

  checkmate::assert_directory_exists(dir)
  checkmate::assert_string(subject_regex)
  checkmate::assert_string(bold_regex)
  checkmate::assert_file_exists(config_yaml)
  checkmate::assert_integerish(ncpus, lower = 1)
  checkmate::assert_integerish(chunksize, lower = 1)
  checkmate::assert_numeric(subj_min, lower = 1)

  pacman::p_load(doFuture, foreach, future.batchtools, iterators, glue, yaml)

  cfg <- yaml::read_yaml(config_yaml)

  if (!file.exists("post_fmriprep.R")) {
    stop("Cannot find required file post_fmriprep.R")
  } else {
    source("post_fmriprep.R")
  }

  sdirs <- grep(subject_regex, list.dirs(dir, recursive = FALSE), value = TRUE, perl = TRUE)
  if (length(sdirs) == 0L) {
    message(glue("No subject directories matching {subject_regex} in {dir}"))
    stop("")
  } else {
    sfiles <- do.call(c, lapply(sdirs, function(ss) {
      list.files(path = ss, pattern = bold_regex, full.names = TRUE, recursive = TRUE)
    }))

    if (scheduler == "slurm") {
      # plan(future.batchtools::batchtools_slurm)
      # https://tdhock.github.io/blog/2019/future-batchtools/
      future::plan(
        tweak(future.batchtools::batchtools_slurm,
          template = "slurm-simple", # good enough for now
          workers = length(sfiles), # one job per file -- can lower this to some fixed value if you want to limit jobs
          resources = list(
            walltime = subj_min * 60 * chunksize, # walltime is in seconds, hence the 60s
            memory = 8000, # 8 GB per core
            ncpus = 1, # always single core per subject
            chunks.as.arrayjobs = FALSE
          )
        )
      )
    } else if (scheduler == "local") {
      future::plan(multisession, workers = ncpus)
    }

    registerDoFuture()
    #registerDoSEQ()

    cat("Processing the following fmriprep BOLD files:\n--------\n\n")
    print(sfiles)
    res <- foreach(ss = iter(sfiles), .packages = c()) %dopar% { # .options.future = list(chunk.size = chunksize)) %dopar% {
      process_subject(ss, cfg = cfg) # process the subject through all steps, return final out_file name
    }

    cat("Finished processing")
  }
}

# post_fmriprep_directory(
#   dir = "/proj/mnhallqlab/studies/bsocial/clpipe/data_fmriprep/fmriprep",
#   bold_regex = "sub-.*_task-clock_run.*desc-preproc_bold\\.nii\\.gz",
#   config_yaml="/proj/mnhallqlab/lab_resources/fmri_processing_scripts/post_fmriprep.yaml"
# )
