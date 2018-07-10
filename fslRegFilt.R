#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if ((length(args)<3)|(length(args)>4)) {
  stop("Expects three arguments (input file, melodic.mix, classified_motion_ICAs) or four arguments (input file, melodic.mix, classified_motion_ICAs, njobs).n", call.=FALSE)
}

library(speedglm)
library(oro.nifti)

partialLm <- function(y, X, ivs=NULL) {
  #bvals <- solve(t(X) %*% X) %*% t(X) %*% y
  #pred <- X[,ivs] %*% bvals[ivs]
  m <- speedlm.fit(y=y, X=X, intercept=FALSE)
  pred <- X[,ivs] %*% coef(m)[ivs]
  return(as.vector(y - pred))
}

#set defaults
njobs <- 4

clustersocketport <- 10290
if (length(args) ==3) {
    dataset <- args[[1]]
    melodic.mix.df<- args[[2]]
    motionpars <- args[[3]]
} else {
    dataset <- args[[1]]
    melodic.mix.df <- args[[2]]
    motionpars <- args[[3]]
    njobs <- as.integer(args[[4]])
}

#dataset <- args[[1]]
print(njobs)
print(dataset)
df <- readNIfTI(dataset, reorient=FALSE)

##melodic.mix.df <- args[[2]]
##motionpars <- args[[3]]
melmix <- data.matrix(read.table(melodic.mix.df, header=FALSE, colClasses="numeric"))
nonconst <- apply(df, c(1,2,3), function(ts) { !all(ts==ts[1]) })
toprocess <- apply(df, 4, function(x) { x[nonconst] })
mi <- which(nonconst==TRUE, arr.ind=TRUE)
badics <- as.numeric(strsplit(scan(motionpars, what="character"), ",")[[1]])

library(doSNOW)
##library(doParallel) 
if (njobs > 1) {
    ##setDefaultClusterOptions(master="localhost", port=clustersocketport)
    cl <- makeSOCKcluster(njobs, outfile = "")
    registerDoSNOW(cl)
    
    ##cl <- parallel::makeCluster(njobs, outfile = "")
    ##registerDoParallel(cl)
} else {
    registerDoSEQ()
}

#cl <- makeSOCKcluster(njobs)
#registerDoSNOW(cl)

#if(njobs >1) {
##toprocess = toprocess[1:100,]

##pb <- txtProgressBar(0, max = nrow(toprocess), style = 3)
##cat("toprocess has: ", nrow(toprocess), "rows\n")
##progress <- function(n) { setTxtProgressBar(pb, n) }
##opts <- list(progress = progress)
#print(opts)

system.time(res <- foreach(v=iter(toprocess, by="row"), .noexport="df", .packages="speedglm", .inorder=TRUE, .multicombine=TRUE, .combine=rbind) %dopar% { #, .options.snow = opts
##system.time(res <- foreach(v=1:nrow(toprocess), .noexport="df", .packages="speedglm", .inorder=TRUE, .multicombine=TRUE, .combine=rbind, .options.snow = opts) %dopar% { 
  ##setTxtProgressBar(pb, v)
  partialLm(matrix(v, ncol=1), melmix, badics)
  ##partialLm(matrix(toprocess[v,], ncol=1), melmix, badics)
})

##close(pb)

if(njobs>1) {
  stopCluster(cl)
}

#temporary assignment to a separate Nifti object
#should probably just overwrite those elements of df in a production setup
abc <- df

#this completely blows the ram...
#abc@.Data <- abind(lapply(data.frame(abc), function(col) {
#            m <- array(0, dim(nonconst)[1:3]) #empty 3d matrix matching dims of images
#            m[nonconst] <- col
#            return(m)
#          }), along=4)

#back to old repmat strategy
miassign <- cbind(pracma::repmat(mi, ncol(res), 1), rep(1:ncol(res), each=nrow(res)))

abc@.Data[miassign] <- res

#add min/max to header to have it play well across packages
abc@cal_min <- min(abc)
abc@cal_max <- max(abc)
writeNIfTI(abc, filename="ica_aroma/denoised_func_data_nonaggr")

                       
