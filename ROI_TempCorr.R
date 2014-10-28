#!/usr/bin/env Rscript

printHelp <- function() {
  cat("ROI_TempCorr is a script that computes temporal correlations among ROIs defined by an integer-valued mask (e.g., a set of numbered spheres).",
      "",
      "Required inputs are:",
      "  -ts  <4D file>: The file containing time series of interest. Usually preprocessed resting-state data. Can be NIfTI or AFNI BRIK/HEAD",
      "  -rois <3D file>: The integer-valued mask file defining the set of ROIs. Computed correlation matrices will be nROIs x nROIs in size based on this mask.",
      "  -out_file <filename for output>: The file to be output containing correlations among ROIs.",
      "",
      "Optional arguments are:",
      "  -roi_reduce <pca|median|mean|huber>: Method to obtain a single time series for voxels within an ROI. Default: pca",
      "      pca takes the first eigenvector within the ROI, representing maximal shared variance",
      "      median uses the median within each ROI",
      "      mean uses the mean within each ROI",
      "      huber uses the huber robust estimate of the center of the distribution (robust to outliers)",
      "  -corr_method <pearson|spearman|robust|mcd|weighted|donostah|M|pairwiseQC|pairwiseGK>: Method to compute correlations among time series. Default: robust",
      "      pearson is the standard Pearson correlation",
      "      spearman is Spearman correlation based on ranks",
      "      kendall is Kendall's tau correlation (also based on ranks, but with somewhat better statistical properties than Spearman)",
      "      robust uses the covRob function from the robust package with estim=\"auto\" to obtain robust estimate of correlation (reduce sensitivity to outliers)",
      "      mcd, weighted, donostah, M, pairwiseQC, pairwiseGK are different robust estimators of correlation. See ?covRob in the robust package for details.",
      "  -fisherz: Apply Fisher's z transformation (arctanh) to normalize correlation coefficients. Not applied by default.",
      "  -brainmask <3D file>: A 0/1 mask file defining voxels in the brain. This will be applied to the ROI mask before computing correlations.",
      "  -njobs <n>: Number of parallel jobs to run when computing correlations. Default: 4.",
      "  -censor <1D file>: An AFNI-style 1D censor file containing a single column of 0/1 values where 0 represents volumes to be censored (e.g., for motion scrubbing)",
      "",
      "If the -ts file does not match the -rois file, the -ts file will be resampled to match the -rois file using 3dresample. This requires that the images be coregistered,",
      "  in the same stereotactic space, and have the same grid size.",
      "",
      "The script depends on the following R libraries: foreach, doSNOW, MASS, oro.nifti, robust, and pracma. These can be installed using:",
      "  install.packages(c(\"foreach\", \"doSNOW\", \"MASS\", \"oro.nifti\", \"robust\", \"pracma\"))",
      sep="\n")
}


#read in command line arguments.
#current format:
#arg 1: config file to process (default current directory)
#arg 2: number of parallel jobs (default 8)
#arg 3: folder containing MRRC reconstructed MB data (rsync from meson)
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0L) {
  message("ROI_TempCorr expects at least -ts <4D file> -rois <3D file> -out_file <filename for output>.\n")
  printHelp()
  quit(save="no", 1, FALSE)
}


#for testing
#fname_rsproc <- "/Users/michael/rest_preproc_mni_example.nii.gz" #name of preprocessed fMRI data
#fname_roimask <- "/Volumes/Serena/bars_ica/scripts/Sci160_FSLMNI_2mm+tlrc.HEAD"
#fname_roimask <- "/Volumes/Serena/bars_ica/scripts/Sci160+tlrc.nii.gz"
#fname_brainmask <- "/Users/michael/standard/fsl_mni152/MNI152_T1_2mm_brain_mask.nii" #optional brain mask to ensure that we don't sample time series from air, CSF, etc.
#fname_censor1D <- "/Volumes/Serena/MMClock/MR_Proc/10637_20140304/mni_5mm_wavelet/clock1/motion_info/censor_union.1D"

#defaults
njobs <- 4
out_file <- "corr_rois.txt" 
fname_censor1D <- NULL
corr_method <- "robust"
roi_reduce <- "pca"
fisherz <- FALSE

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
    corr_method <- args[argpos + 1]
    argpos <- argpos + 2
    stopifnot(corr_method %in% c("pearson", "spearman", "robust", "kendall", "mcd", "weighted", "donostah", "M", "pairwiseQC", "pairwiseGK"))    
  } else if (args[argpos] == "-fisherz") {
    fisherz <- TRUE
    argpos <- argpos + 1
  } else {
    stop("Not sure what to do with argument: ", args[argpos])
  }
}

if (corr_method == "robust") { corr_method <- "auto" } #robust package uses "auto" to choose best robust estimator given problem complexity (matrix size)

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

#generate (robust) correlation matrix given a set of time series.
genCorrMat <- function(roits, method="auto", fisherz=FALSE) {
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
  
  #Due to rank degeneracy of many RS-fcMRI roi x time matrices, correlations are filled in pairwise.
  #This is slow, of course, but necessary.
  rcorMat <- matrix(NA, nrow=ncol(nona), ncol=ncol(nona))
  diag(rcorMat) <- 1
  
  #indices of lower triangle
  lo.tri <- which(lower.tri(rcorMat), arr.ind=TRUE)
  
  chunksPerProcessor <- 8
  #do manual chunking: divide correlations across processors, where each processor handles 10 chunks in total (~350 corrs per chunk)
  corrvec <- foreach(pair=iter(lo.tri, by="row", chunksize=floor(nrow(lo.tri)/njobs/chunksPerProcessor)), .inorder=TRUE, .combine=c, .multicombine=TRUE, .packages="robust") %dopar% {
    #iter will pass entire chunk of lo.tri, use apply to compute row-wise corrs
    #basic cor for testing (much faster)
    if (method %in% c("pearson", "spearman", "kendall")) {
      apply(pair, 1, function(x) cor(na.omit(cbind(nona[,x[1]], nona[,x[2]])), method=method)[1,2])  
    } else {
      apply(pair, 1, function(x) covRob(na.omit(cbind(nona[,x[1]], nona[,x[2]])), estim=method, corr=TRUE)$cov[1,2])
    }
  }
  
  #populate lower triangle of correlation matrix
  if (fisherz == TRUE) { 
    message("Applying the Fisher z transformation to correlation coefficients.")
    corrvec <- atanh(corrvec)
  }
  rcorMat[lo.tri] <- corrvec
  #duplicate the lower triangle to upper
  rcorMat[upper.tri(rcorMat)] <- t(rcorMat)[upper.tri(rcorMat)] #transpose flips filled lower triangle to upper
  
  #add back in NA cols
  if (length(nacols) > 0) {
    processedCorrs <- matrix(NA, nrow=ncol(roits), ncol=ncol(roits))
    #for complete redundancy (haha), insert NA for the row and col of each na time series in the original
    #processedCorrs[nacols,] <- NA
    #processedCorrs[,nacols] <- NA
    
    #fill in all non-NA cells row-wise
    processedCorrs[!1:ncol(roits) %in% nacols, !1:ncol(roits) %in% nacols] <- rcorMat
  } else processedCorrs <- rcorMat
  
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
  roimask <- readNIfTI(fname_roimask)
}

#optional: apply brain mask
if (!is.null(fname_brainmask)) {
  message("Applying brain mask to ROIs: ", fname_brainmask)
  stopifnot(file.exists(fname_brainmask))
  if (grepl("^.*\\.(HEAD|BRIK|BRIK.gz)$", fname_brainmask, perl=TRUE)) {
    brainmask <- readAFNI(fname_brainmask)
  } else {
    brainmask <- readNIfTI(fname_brainmask)
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
  rsproc <- readNIfTI(fname_rsproc)
}

if (!identical(dim(rsproc)[1:3], dim(roimask)[1:3])) {
  message("Resampling rs proc file from: ", paste(dim(rsproc)[1:3], collapse="x"), " to: ", paste(dim(roimask)[1:3], collapse="x"), " using nearest neighbor")
  message("This assumes that the files are in the same space and have the same grid size. Make sure this is what you want!!")
  
  runAFNICommand(paste0("3dresample -overwrite -inset ", fname_rsproc, " -rmode NN -master ", fname_roimask, " -prefix tmpResamp.nii.gz"))
  stopifnot(file.exists("tmpResamp.nii.gz"))
  
  rsproc <- readNIfTI("tmpResamp.nii.gz")
  unlink("tmpResamp.nii.gz")
}

#obtain vector of mask values 
maskvals <- sort(unique(as.vector(roimask)))
maskvals <- maskvals[which(maskvals != 0)] #omit zero

if (length(maskvals) > 1000) {
  warning("More than 1000 putative ROIs identified in mask file: ", fname_roimask)
}

setDefaultClusterOptions(master="localhost", port=10290)
clusterobj <- makeSOCKcluster(njobs)
registerDoSNOW(clusterobj)


#should really apply censor here to entire 4d volume
if (length(censorVols) > 0L) {
  message("Censoring volumes ", paste0(censorVols, collapse=", "), " based on ", fname_censor1D)
  goodVols <- 1:dim(rsproc)[4]
  goodVols <- goodVols[-censorVols]
  rsproc <- rsproc[,,,goodVols] #keep orig in memory? 
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
        })

rm(rsproc) #clear imaging file from memory now that we have obtained the roi time series 
    
message("Obtaining a single time series within each ROI using: ", roi_reduce)
roimat <- foreach(roivox=iter(roimats), .packages=c("MASS"), .combine=cbind, .noexport=c("rsproc")) %dopar% {
  if (roi_reduce == "pca") {
    ts <- prcomp(roivox)$rotation[,1] #first eigenvector  
  } else if (roi_reduce == "mean") {
    ts <- apply(roivox, 2, mean, na.rm=TRUE)
  } else if (roi_reduce == "median") {
    ts <- apply(roivox, 2, median, na.rm=TRUE)
  } else if (roi_reduce == "huber") {
    ts <- apply(roivox, 2, getRobLocation)
  }
  
  return(ts)
}

colnames(roimat) <- paste0("roi", maskvals)
rownames(roimat) <- paste0("vol", 1:nrow(roimat))

message("Computing correlations among ROI times series using method: ", ifelse(corr_method=="auto", "robust", corr_method))
cormat <- genCorrMat(as.data.frame(roimat), method=corr_method, fisherz=fisherz)

stopCluster(clusterobj)

message("Writing correlations to: ", out_file)
write.table(cormat, file=out_file, col.names=FALSE, row.names=FALSE)
