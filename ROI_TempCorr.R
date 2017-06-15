#!/usr/bin/env Rscript

# run like
# ./ROI_TempCorr.R -ts /Volumes/Phillips/WorkingMemory/11155/20130418/SpatialWM_v1_run1_768x720.5/nfswkmtd_functional.nii.gz -brainmask  /Volumes/Phillips/gm_50mask.nii 

printHelp <- function() {
  cat("ROI_TempCorr is a script that computes temporal correlations among ROIs defined by an integer-valued mask (e.g., a set of numbered spheres).",
      "",
      "Required inputs are:",
      "  -ts       <4D file>: The file containing time series of interest. Usually preprocessed resting-state data. Can be NIfTI or AFNI BRIK/HEAD",
      "  -rois <3D file>: The integer-valued mask file defining the set of ROIs. Computed correlation matrices will be nROIs x nROIs in size based on this mask.",
      "  -out_file <filename for output>: The file to be output containing correlations among ROIs.",
      "",
      "Optional arguments are:",
      "  -pcorr_method <pearson|spearman|kendall|adalasso.net|lasso.net|pls.net|ridge.net|pcor.shrink>: Method to compute partial correlation",
      "      pearson, spearman, and kendall compute the corresponding partial correlations (pcor function in ppcor package). BEWARE: Uses pseudoinverse for rank-deficient matrices.",
      "      adalasso.net uses adaptive LASSO regression with cross-validation to compute partial correlations (adalasso.net function in parcor package)",
      "      lasso.net uses LASSO regression (no adaptation) with cross-validation to compute partial correlations (adalasso.net function in parcor package)",
      "      pls.net uses partial least squares regression models to estimate partial correlations (pls.net function in parcor package)",
      "      ridge.net uses optimal ridge regression models to estimate partial correlations (ridge.net function in parcor package",
      "  -pcorr_cvsplit <10>: For adalasso.net, lasso.net, pls.net, and ridge.net methods, the number of splits for k-fold cross-validation.",      
      "  -corr_method <pearson|spearman|kendall|robust|mcd|weighted|donostah|M|pairwiseQC|pairwiseGK|cor.shrink>: Method to compute correlations among time series.",
      "      Default: pearson is the standard Pearson correlation",
      "      spearman is Spearman correlation based on ranks",
      "      kendall is Kendall's tau correlation (also based on ranks, but with somewhat better statistical properties than Spearman)",
      "      robust uses the covRob function from the robust package with estim=\"auto\" to obtain robust estimate of correlation (reduce sensitivity to outliers)",
      "      mcd, weighted, donostah, M, pairwiseQC, pairwiseGK are different robust estimators of correlation. See ?covRob in the robust package for details.",
      "      cor.shrink computes a shrinkage estimate of the correlation matrix by shrinking correlations towards the identity matrix. See ?cor.shrink in the corpcor package.",
      "  -roi_reduce <pca|median|mean|huber>: Method to obtain a single time series for voxels within an ROI. Default: pca",
      "      pca takes the first eigenvector within the ROI, representing maximal shared variance",
      "      median uses the median within each ROI",
      "      mean uses the mean within each ROI",
      "      huber uses the huber robust estimate of the center of the distribution (robust to outliers)",
      "  -brainmask <3D file>: A 0/1 mask file defining voxels in the brain. This will be applied to the ROI mask before computing correlations.",
      "  -dropvols <integer=0>: The number of initial volumes to drop from all voxel time series prior to computing correlations (e.g., for steady state problems)",
      "  -censor <1D file>: An AFNI-style 1D censor file containing a single column of 0/1 values where 0 represents volumes to be censored (e.g., for motion scrubbing)",
      "  -fisherz: Apply Fisher's z transformation (arctanh) to normalize correlation coefficients. Not applied by default.",
      "  -njobs <n>: Number of parallel jobs to run when computing correlations. Default: 4.",
      "  -na_string: Character string indicating how to represent missing correlations in output file. Default NA.",
      "  -ts_out_file <filename for time series output>: Output a file containing the average time series for each region before computing correlations.",
      "  -ts_only: stop before running correlations. useful with -ts_out_file",
      "",
      "If the -ts file does not match the -rois file, the -ts file will be resampled to match the -rois file using 3dresample. This requires that the images be coregistered,",
      "  in the same stereotactic space, and have the same grid size.",
      "",
      "Multiple correlation methods can be computed at once by passing a comma-separated list. Both partial and full correlations computation can also be combined.",
      "  Example: -corr_method pearson,cor.shrink -pcor_method pcor.shrink,adalasso.net",
      "",
      "The script depends on the following R libraries: foreach, doSNOW, MASS, oro.nifti, parcor, ppcor, pracma, and robust. These can be installed using:",
      "  install.packages(c(\"foreach\", \"doSNOW\", \"MASS\", \"oro.nifti\", \"parcor\", \"ppcor\", \"pracma\", \"ppcor\", \"robust\"))",
      sep="\n")
}


#read in command line arguments.
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0L) {
  message("ROI_TempCorr expects at least -ts <4D file> -rois <3D file> -out_file <filename for output>.\n")
  printHelp()
  quit(save="no", 1, FALSE)
}

#for testing
#fname_rsproc <- "/gpfs/group/mnh5174/default/Raj/Preprocess_Rest/10638_20140507/brnswudktm_rest_5.nii.gz" #name of preprocessed fMRI data
#fname_roimask <- "/gpfs/group/mnh5174/default/Raj/Preprocess_Rest/power264_mni2.3mm.nii.gz"
#fname_brainmask <- "/gpfs/group/mnh5174/default/lab_resources/standard/mni_icbm152_nlin_asym_09c/mni_icbm152_t1_tal_nlin_asym_09c_mask_2.3mm.nii"
#fname_censor1D <- "/gpfs/group/mnh5174/default/MMClock/MR_Proc/10637_20140304/mni_5mm_wavelet/clock1/motion_info/censor_union.1D"

#defaults
njobs <- 4
out_file <- "corr_rois.txt"
ts_out_file <- ""
fname_censor1D <- NULL
fname_brainmask <- NULL
cm <- "pearson"
cm_partial <- FALSE #TRUE for partial correlation methods
pm <- c()
pm_partial <- c()
roi_reduce <- "pca"
fisherz <- FALSE
dropvols <- 0
pcorr_cvsplit <- 10 #default 10-fold cross-validation for parcor functions
ts_only <- FALSE # only compute timeseries, not correlation matrix

na_string <- "NA"
clustersocketport <- 10290

argpos <- 1
while (argpos <= length(args)) {
  if (args[argpos] == "-ts") {
    fname_rsproc <- args[argpos + 1] #name of preprocessed fMRI data
    stopifnot(file.exists(fname_rsproc))
    argpos <- argpos + 2
  } else if (args[argpos] == "-rois") {
    fname_roimask <- args[argpos + 1] #name of integer-valued ROI mask file
    argpos <- argpos + 2
    stopifnot(file.exists(fname_roimask))
  } else if (args[argpos] == "-out_file") {
    out_file <- args[argpos + 1] #name of file to be written
    argpos <- argpos + 2
  } else if (args[argpos] == "-ts_out_file") {
    ts_out_file <- args[argpos + 1] #name of file to be written
    argpos <- argpos + 2
  } else if (args[argpos] == "-censor") {
    fname_censor1D <- args[argpos + 1] #name of censor file
    argpos <- argpos + 2
    stopifnot(file.exists(fname_censor1D))
  } else if (args[argpos] == "-brainmask") {
    fname_brainmask <- args[argpos + 1] #mask file for brain voxels
    argpos <- argpos + 2
    stopifnot(file.exists(fname_brainmask))    
  } else if (args[argpos] == "-njobs") {
    njobs <- as.integer(args[argpos + 1])
    argpos <- argpos + 2
    if (is.na(njobs)) { stop("-njobs must be an integer") }
  } else if (args[argpos] == "-roi_reduce") {
    roi_reduce <- args[argpos + 1]
    argpos <- argpos + 2
    stopifnot(roi_reduce %in% c("pca", "mean", "median", "huber"))
  } else if (args[argpos] == "-corr_method") {
    cm <- strsplit(args[argpos + 1], ",")[[1]]
    cm_partial <- rep(FALSE, length(cm))
    argpos <- argpos + 2
    stopifnot(all(cm %in% c("pearson", "spearman", "robust", "kendall", "mcd", "weighted", "donostah", "M", "pairwiseQC", "pairwiseGK", "cor.shrink")))
  } else if (args[argpos] == "-pcorr_method") {
    pm <- strsplit(args[argpos + 1], ",")[[1]]
    pm_partial <- rep(TRUE, length(pm))
    argpos <- argpos + 2
    stopifnot(all(pm %in% c("pearson", "spearman", "kendall", "adalasso.net", "lasso.net", "pls.net", "ridge.net", "pcor.shrink")))
  } else if (args[argpos] == "-pcorr_cvsplit") {
    pcorr_cvsplit <- as.numeric(args[argpos + 1])
    if (is.na(pcorr_cvsplit)) { stop("Could not understand argument ", args[argpos+1], "to -pcorr_cvsplit") }
    argpos <- argpos + 2
  } else if (args[argpos] == "-fisherz") {
    fisherz <- TRUE
    argpos <- argpos + 1
  } else if (args[argpos] == "-ts_only") {
    ts_only <- TRUE
    argpos <- argpos + 1
  } else if (args[argpos] == "-na_string") {
    na_string <- args[argpos + 1]
    argpos <- argpos + 2
  } else if (args[argpos] == "-dropvols") {
    dropvols <- as.numeric(args[argpos + 1]) #number of vols to drop
    if (is.na(dropvols)) { stop("Could not understand argument ", args[argpos+1], "to -dropvols") }
    argpos <- argpos + 2
  } else if (args[argpos] == "-port") {
    clustersocketport <- as.integer(args[argpos + 1])
    argpos <- argpos + 2
    if (is.na(njobs)) { stop("-port must be an integer") }
  } else {
    stop("Not sure what to do with argument: ", args[argpos])
  }
}

corr_method <- c(cm, pm) #put together full and partial methods
partial <- c(cm_partial, pm_partial)

#robust package uses "auto" to choose best robust estimator given problem complexity (matrix size)
corr_method <- ifelse(corr_method == "robust", "auto", corr_method)

# check for input sanity before spending time loading things in
if (ts_only && nchar(ts_out_file) == 0L) {
  stop('-ts_only is set without -ts_out_file! No point in running.')
}

suppressMessages(require(methods))
suppressMessages(require(foreach))
suppressMessages(require(doSNOW))
suppressMessages(require(MASS))
suppressMessages(require(oro.nifti))
suppressMessages(require(pracma))

if (!is.null(fname_censor1D)) {
  stopifnot(file.exists(fname_censor1D))
  censor1D <- read.table(fname_censor1D, header=FALSE)$V1
  censorVols <- which(censor1D == 0.0)      
} else {
  censorVols <- c()
}

#generate (robust or partial) correlation matrix given a set of time series.
genCorrMat <- function(roits, method="auto", fisherz=FALSE, partial=FALSE) {
  #roits should be an time x roi data.frame
  
  suppressMessages(require(robust))

  #assume that parallel has been setup upstream
  njobs <- getDoParWorkers()
  
  #sapply only works for data.frame
  if (!inherits(roits, "data.frame")) stop("genCorrMat only works properly with data.frame objects.")

  #remove missing ROI columns for estimating correlation
  nacols <- which(sapply(roits, function(col) all(is.na(col))))
  if (length(nacols) > 0) nona <- roits[,nacols*-1]
  else nona <- roits
  
  #All partial correlation methods are necessarily full matrix methods (since partial correlation is conditioned on remaining variables)
  #Standard correlations are also computed on full matrices. Only the robust estimators of correlation blow up on singular matrices
  if (method %in% c("pearson", "spearman", "kendall", "cor.shrink", "pcor.shrink", "adalasso.net", "lasso.net", "pls.net", "ridge.net")) {
    pairwise <- FALSE
  } else {
    #estimators using covRob from robust package tend to expect positive definite matrix
    pairwise <- TRUE
  }

  if (method %in% c("cor.shrink", "pcor.shrink")) { stopifnot(require(corpcor))
  } else if (method %in% c("adalasso.net", "lasso.net", "pls.net", "ridge.net")) { stopifnot(suppressMessages(require(parcor))) }
  
  if (!pairwise) {
    if (method=="cor.shrink") {
      message("Estimating shrinkage estimates (always positive definite) of correlation matrix using cor.shrink")
      rcorMat <- corpcor::cor.shrink(as.matrix(nona)) #omit lambda to estimate shrinkage using analytic formula
    } else if (method=="pcor.shrink") {
      message("Estimating shrinkage estimates (always positive definite) of partial correlation matrix using pcor.shrink")
      rcorMat <- corpcor::pcor.shrink(as.matrix(nona)) #omit lambda to estimate shrinkage using analytic formula
    } else if (method=="adalasso.net") {
      rcorMat <- parcor::adalasso.net(as.matrix(nona), k=pcorr_cvsplit, both=TRUE)$pcor.adalasso
    } else if (method=="lasso.net") {
      rcorMat <- parcor::adalasso.net(as.matrix(nona), k=pcorr_cvsplit, both=FALSE)$pcor.lasso
    } else if (method=="pls.net") {
      rcorMat <- parcor::pls.net(as.matrix(nona), k=pcorr_cvsplit)$pcor
    } else if (method=="ridge.net") {
      rcorMat <- parcor::ridge.net(as.matrix(nona), k=pcorr_cvsplit)$pcor
    } else if (partial) {
      stopifnot(require(ppcor))
      message("ppcor pcor func")
      rcorMat <- ppcor::pcor(as.matrix(nona), method=method)
    } else {
      #conventional cor using specified method
      rcorMat <- cor(as.matrix(nona), method=method)
    }

    #adalasso.net(X, k = 10,use.Gram=FALSE,both=TRUE,verbose=FALSE,intercept=TRUE)
    #ridge.net(X, lambda, plot.it = FALSE, scale = TRUE, k = 10,verbose=FALSE)
    #pls.net(X, scale = TRUE, k = 10, ncomp = 15,verbose=FALSE)

    #come back to this: diagnostics on partial correlation?
    #if (partial) {
    #  require(parcor)
    #  #at the moment, GeneNet does not expose ggm.test.edges, so set fdr=FALSE to avoid crash
    #  perf <- parcor::performance.pcor(rcorMat, true.pcor=NULL, fdr=FALSE, cutoff.ggm=0.8, verbose=FALSE, plot.it=FALSE)
    #  print(perf)
    #}
  } else {
    
    #Due to rank degeneracy of many RS-fcMRI roi x time matrices, correlations are sometimes filled in pairwise.
    #This is slow, of course, but necessary.
    rcorMat <- matrix(NA, nrow=ncol(nona), ncol=ncol(nona))
    diag(rcorMat) <- 1
    
    #indices of lower triangle
    lo.tri <- which(lower.tri(rcorMat), arr.ind=TRUE)
    
    # how many chucks per core
    # for small datasets, need to make sure we didn't pick too high a number
    chunksPerProcessor <- 8

    # if we only have one job, we want all the chunks together
    # that is we want chunksize == nrow(lo.tri)
    if(njobs == 1) { chunksPerProcessor <- 1 }

    repeat {
      chunksize <- floor(nrow(lo.tri)/njobs/chunksPerProcessor)
      if(chunksize >= 1) break
      # decrease chunk size and check we can still go lower
      chunksPerProcessor <- chunksPerProcessor - 1
      cat('WARNING: job is small, decreasing chunks to',chunksPerProcessor,'\n')
      if(chunksPerProcessor<1) stop('too many jobs for too little work, lower -n')
    }

    # let us know when we are asking for a lot of work
    # the threshold is less for non-full cor types
    chunksizewarn <- 10^3
    if (chunksize > chunksizewarn) warning(sprintf('lots of datapoints (%d) going to each processor',chunksize))

    #do manual chunking: divide correlations across processors, where each processor handles 10 chunks in total (~350 corrs per chunk)
    corrvec <- foreach(pair=iter(lo.tri, by="row", chunksize=chunksize), .inorder=TRUE, .combine=c, .multicombine=TRUE, .packages="robust") %dopar% {
      #iter will pass entire chunk of lo.tri, use apply to compute row-wise corrs
      apply(pair, 1, function(x) covRob(na.omit(cbind(nona[,x[1]], nona[,x[2]])), estim=method, corr=TRUE)$cov[1,2])
    }
    
    rcorMat[lo.tri] <- corrvec
    #duplicate the lower triangle to upper
    rcorMat[upper.tri(rcorMat)] <- t(rcorMat)[upper.tri(rcorMat)] #transpose flips filled lower triangle to upper
  }
  
  #populate lower triangle of correlation matrix
  if (fisherz == TRUE) { 
    message("Applying the Fisher z transformation to correlation coefficients.")
    rcorMat <- atanh(rcorMat)
    diag(rcorMat) <- 15 #avoid Inf in output by a large value. tanh(15) is ~1
  }
  
  #add back in NA cols
  if (length(nacols) > 0) {
    processedCorrs <- matrix(NA, nrow=ncol(roits), ncol=ncol(roits))
    
    #fill in all non-NA cells row-wise
    processedCorrs[!1:ncol(roits) %in% nacols, !1:ncol(roits) %in% nacols] <- rcorMat
  } else { processedCorrs <- rcorMat }
  
  processedCorrs #return processed correlations
  
}

#robust estimate of location (center) of distribution
getRobLocation <- function(vec, type="huber", k=3.0) {
  require(MASS)
  if (all(is.na(vec))) return(NA_real_)
  else if (type=="huber") return(huber(vec, k=k)$mu)
  else if (type=="median") return(median(vec, na.rm=TRUE))
}

#wrapper for running an AFNI command safely within R
#if AFNI does not have its environment setup properly, commands may not work
runAFNICommand <- function(args, afnidir=NULL, stdout=NULL, stderr=NULL) {
  #look for AFNIDIR in system environment if not passed in
  if (is.null(afnidir)) {
    env <- system("env", intern=TRUE)
    if (length(afnidir <- grep("^AFNIDIR=", env, value=TRUE)) > 0L) {
      afnidir <- sub("^AFNIDIR=", "", afnidir)
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
  retcode <- system(afnicmd)
  return(retcode)
}



### BEGIN DATA PROCESSING
message("Reading roi mask: ", fname_roimask)
if (grepl("^.*\\.(HEAD|BRIK|BRIK.gz)$", fname_roimask, perl=TRUE)) {
  roimask <- readAFNI(fname_roimask, vol=1)
  #afni masks tend to read in as 4D matrix with singleton 4th dimension. Fix this
  if (length(dim(roimask)) == 4L) {
    roimask@.Data <- roimask[,,,,drop=T]    
  }
} else {
  roimask <- readNIfTI(fname_roimask, reorient=FALSE)
}

#optional: apply brain mask
if (!is.null(fname_brainmask)) {
  message("Applying brain mask to ROIs: ", fname_brainmask)
  stopifnot(file.exists(fname_brainmask))
  if (grepl("^.*\\.(HEAD|BRIK|BRIK.gz)$", fname_brainmask, perl=TRUE)) {
    brainmask <- readAFNI(fname_brainmask)
  } else {
    brainmask <- readNIfTI(fname_brainmask, reorient=FALSE)
  }
  
  #brain mask and roi mask must be of same dimension
  stopifnot(identical(dim(brainmask)[1:3], dim(roimask)[1:3]))

  message("  ROI voxels before applying brainmask: ", sum(roimask > 0, na.rm=TRUE))
  
  #remove non-brain voxels
  roimask[which(brainmask == 0.0)] <- NA_real_
  
  message("  ROI voxels after applying brainmask:  ", sum(roimask > 0, na.rm=TRUE))
  
}

message("Reading in 4D file: ", fname_rsproc)
#read in processed resting-state data
if (grepl("^.*\\.(HEAD|BRIK|BRIK.gz)$", fname_rsproc, perl=TRUE)) {
  rsproc <- readAFNI(fname_rsproc)
} else {
  rsproc <- readNIfTI(fname_rsproc, reorient=FALSE)
}

if (!identical(dim(rsproc)[1:3], dim(roimask)[1:3])) {
  message("Resampling rs proc file from: ", paste(dim(rsproc)[1:3], collapse="x"), " to: ", paste(dim(roimask)[1:3], collapse="x"), " using nearest neighbor")
  message("This assumes that the files are in the same space and have the same grid size. Make sure this is what you want!!")
  
  runAFNICommand(paste0("3dresample -overwrite -inset ", fname_rsproc, " -rmode NN -master ", fname_roimask, " -prefix tmpResamp.nii.gz"))
  stopifnot(file.exists("tmpResamp.nii.gz"))
  
  rsproc <- readNIfTI("tmpResamp.nii.gz", reorient=FALSE)
  unlink("tmpResamp.nii.gz")
}

#obtain vector of mask values 
maskvals <- sort(unique(as.vector(roimask)))
maskvals <- maskvals[which(maskvals != 0)] #omit zero

if (length(maskvals) > 1000) {
  warning("More than 1000 putative ROIs identified in mask file: ", fname_roimask)
}

if (njobs > 1) {
    setDefaultClusterOptions(master="localhost", port=clustersocketport)
    clusterobj <- makeSOCKcluster(njobs)
    registerDoSNOW(clusterobj)
} else {
    registerDoSEQ()
}

#to reduce RAM overhead of having to copy rsproc_censor to each worker, obtain list of vox x time mats for rois

#even though this seems more elegant, it is much slower (400x!) than the use of 4d lookup and reshape below
#system.time(roimats <- lapply(maskvals, function(v) {
#      apply(rsproc, 4, '[', which(roimask==v, arr.ind=TRUE))
#    }))

#generate a 4d mat of indices
roimats <- lapply(maskvals, function(v) {
  mi <- which(roimask==v, arr.ind=TRUE)
  nvol <- dim(rsproc)[4]
  nvox <- nrow(mi)
  mi4d <- cbind(pracma::repmat(mi, nvol, 1), rep(1:nvol, each=nvox))
  mat <- matrix(rsproc[mi4d], nrow=nvox, ncol=nvol) #need to manually reshape into matrix from vector
  attr(mat, "maskval") <- v #add mask value as attribute so that information about bad ROIs can be printed below
  t(mat) #transpose matrix so that it is time x voxels
})

rm(rsproc) #clear imaging file from memory now that we have obtained the roi time series 

message("Obtaining a single time series within each ROI using: ", roi_reduce)
roiavgmat <- foreach(roivox=iter(roimats), .packages=c("MASS"), .combine=cbind, .noexport=c("rsproc")) %do% { #minimal time savings from dopar here, and it prevents message output
  ##roivox is a time x voxels matrix
  ##data cleaning steps: remove voxels that are 1) partially or completely missing; 2) all 0; 3) variance = 0 (constant)
  ##leave out variance > mean check because bandpass-filtered data are demeaned
  badvox <- apply(roivox, 2, function(voxts) {
    if (any(is.na(voxts))) TRUE #any missing values
    else if (all(voxts == 0.0)) TRUE #all zeros
    else if (var(voxts) == 0.0) TRUE #constant time series
    ##else if (var(voxts) > mean(voxts)) TRUE #variance exceeds mean (very unstable)
    else FALSE #good voxel
  })

  if (sum(!badvox) < 5) {
    ##only reduce if there are at least 5 voxels to average over after reduction above
    ##otherwise return NA time series

    ##cat("  ROI ", attr(roivox, "maskval"), ": fewer than 5 voxels had acceptable time series. Removing this ROI from correlations.\n", file=".roilog", append=TRUE)
    message("  ROI ", attr(roivox, "maskval"), ": fewer than 5 voxels had acceptable time series. Removing this ROI from correlations.")
    ts <- rep(NA_real_, nrow(roivox))
  } else {
    if (sum(badvox) > 0) {
      ##cat("  ROI ", attr(roivox, "maskval"), ": ", sum(badvox), " voxels had bad time series (e.g., constant) and were removed prior to ROI averaging.\n", file=".roilog", append=TRUE)
      message("  ROI ", attr(roivox, "maskval"), ": ", sum(badvox), " voxels had bad time series (e.g., constant) and were removed prior to ROI averaging.")
      roivox <- roivox[,!badvox] #remove bad voxels (columns)
    }

    if (roi_reduce == "pca") {
      ts <- prcomp(roivox, scale.=TRUE)$x[,1] #first eigenvector
      tsmean <- apply(roivox, 1, mean, na.rm=TRUE)
      #flip sign of component to match observed data (positive correlation)
      if (cor(ts, tsmean) < 0) { ts <- -1*ts }
    } else if (roi_reduce == "mean") {
      ts <- apply(roivox, 1, mean, na.rm=TRUE) #mean time series across voxels
    } else if (roi_reduce == "median") {
      ts <- apply(roivox, 1, median, na.rm=TRUE)
    } else if (roi_reduce == "huber") {
      ts <- apply(roivox, 1, getRobLocation)
    }
  }

  return(ts)
}

#need to print roi problems outside of foreach since stdout is dumped
#roimessages <- readLines(".roilog")
#cat(roimessages)
#unlink(".roilog")

colnames(roiavgmat) <- paste0("roi", maskvals)
rownames(roiavgmat) <- paste0("vol", 1:nrow(roiavgmat))

##apply censoring to resulting time series
censorvec <- rep(0, nrow(roiavgmat))
goodVols <- 1:nrow(roiavgmat)

if (length(censorVols) > 0L) {
  message("Censoring volumes ", paste0(censorVols, collapse=", "), " based on ", fname_censor1D)
  goodVols <- goodVols[-censorVols]
  censorvec[censorVols] <- 1
}

##drop initial volumes if requested
if (dropvols > 0) {
  message("Dropping ", dropvols, " volumes from ROI time series prior to correlation.")
  goodVols <- goodVols[-1*(1:dropvols)]
  censorvec[1:dropvols] <- 1
}

roiavgmat_censored <- roiavgmat[goodVols,]

##output ts file if requested
if (nchar(ts_out_file) > 0L) {
  message("Writing time series to: ", ts_out_file)
  if(is.null(fname_censor1D)) {
    df <- roiavgmat
  } else {
    df <- cbind(censor=censorvec, roiavgmat)
  }
  write.table(df, file=ts_out_file, col.names=F, row.names=F)
}

#If we only want the timeseries, quit before computing correlations
if (ts_only) {
    try(stopCluster(clusterobj))
    quit(save="no", 0, FALSE)
}

pp <- ifelse(partial==TRUE, "_partial", "") #insert 'partial' into message and file name if relevant
for (m in 1:length(corr_method)) {
  message("Computing", sub("_", " ", pp[m]), " correlations among ROI times series using method: ", ifelse(corr_method[m]=="auto", "robust", corr_method[m]))
  cormat <- genCorrMat(as.data.frame(roiavgmat_censored), method=corr_method[m], fisherz=fisherz, partial=partial[m])
  this_out_file <- sub("((\\.[^.\\s]+)+)$", paste0("_", corr_method[m], pp[m], "\\1"), out_file) #add correlation-specific suffix to file
  message("Writing correlations to: ", this_out_file)
  if (grepl(".*\\.gz$", this_out_file, perl=TRUE)) {
    ##write compressed
    gzf <- gzfile(this_out_file, "w")
    write.table(cormat, file=gzf, col.names=FALSE, row.names=FALSE, na=na_string)
    close(gzf)    
  } else {
    write.table(cormat, file=this_out_file, col.names=FALSE, row.names=FALSE, na=na_string)
  }
}

if (njobs > 1) { try(stopCluster(clusterobj)) }
quit(save="no", 0, FALSE)
