#!/usr/bin/env Rscript

#create symbolic links to directories that can be matched againt the original directories
#mb recon produces directories such as: WPC5640-01302014-11243
#original dicom dirs have form: 11243_20140130

args <- commandArgs(trailingOnly = TRUE)

stopifnot(length(args) == 1L)
goto <- args[1L]
if (! file.exists(goto)) { stop("Cannot find directory: ", goto) }
setwd(goto)

origdirs <- list.dirs(getwd(), recursive=FALSE)
whichlinks <- Sys.readlink(origdirs) != ""
origdirs <- origdirs[!whichlinks] #omit symbolic links to avoid re-creating them

#print(origdirs)

for (d in origdirs) {
    d_base <- basename(d)
    proto_code <- sub("^([^-]+)-[^-]+-[^-]+.*$", "\\1", d_base, perl=TRUE)
    date <- sub("^[^-]+-([^-]+)-[^-]+$", "\\1", d_base, perl=TRUE)
    newdate <- paste0(substr(date, 5, 8), substr(date, 1, 4))
    s_id <- sub("^[^-]+-[^-]+-([^-_]+).*$", "\\1", d_base, perl=TRUE)
    newfmt <- paste(proto_code, s_id, newdate, sep="_")
    if (is.na(Sys.readlink(newfmt))) { file.symlink(d_base, newfmt) }
}
