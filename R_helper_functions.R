runAFNICommand <- function(args, afnidir=NULL, stdout=NULL, stderr=NULL, ...) {
    ##look for AFNIDIR in system environment if not passed in
    if (is.null(afnidir)) {
        env <- system("env", intern=TRUE)
        if (length(afnidir <- grep("^AFNIDIR=", env, value=TRUE)) > 0L) {
            afnidir <- sub("^AFNIDIR=", "", afnidir)
        } else if (nchar(afniloc <- suppressWarnings(system("which afni", intern=TRUE))) > 0L) {
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
