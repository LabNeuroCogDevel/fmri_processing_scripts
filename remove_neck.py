#!/usr/bin/env python
# * Imports
# numpy and plotting
# also need something to smooth
import sys
import nipy
import numpy as np
from scipy.signal import argrelextrema
from argparse import ArgumentParser, BooleanOptionalAction

# * Inputs
# for testing we used
# fname = '/Volumes/Hera/Datasets/UCI_OHSU/bids/sub-2002/anat/sub-2002_T1w.nii.gz'
# outfile = 'no_neck.nii.gz'
argpar = ArgumentParser()
argpar.add_argument('infile', nargs=1, help="input image with too much neck")
argpar.add_argument('outfile', help="output file name", default="no_neck.nii.gz", nargs='?')
argpar.add_argument('--showplot', help="show plot?", default=False, action=BooleanOptionalAction)
args = argpar.parse_args(sys.argv[1:])
fname=args.infile[0]
outfile=args.outfile
print(args)

nii = nipy.load_image(fname)
no_neck =  nipy.load_image(fname) # todo: correct way to make a copy (or reuse nii)

# * Algo
# <2021-06-15 Tue> initial testing
# Want to cut out all but head.
# If we combine all the coronal slices, we'll hopefully get a good measure of the shape: head to neck to shoulders.
# From there, we can hopefully find the thinnest width (neck) and zero out anything below it.

# ** Outline
# coronal slices mashed together
coronal = np.mean(nii, axis=1)

# % covered by brain/body
# looking for local minimum - the area between body and brain
coronal_mask = coronal > np.mean(coronal)

# ** Neck location
# we get a histogram of coverage (line) and
# smooth the line by convolving with a flat hat
# window size was picked arbitrarily.
line_coverage = np.sum(coronal_mask, axis=0)
win_sz = 30
hat = np.ones(win_sz,'d')/win_sz # flat
line_smooth = np.convolve(hat, line_coverage)[win_sz:]
mins = argrelextrema(line_smooth, np.less)[0]
neck_at = mins[-1] + int(win_sz/4) # a little higher up than actual

# ** Cut
no_neck.get_data()[:,:,0:neck_at] = 0
_ = nipy.save_image(no_neck, outfile, dtype_from='header')


# ** Plot
if not args.showplot:
    sys.exit()

import matplotlib.pyplot as plt
def im(i, x, **kargs):
    """subplot of nii slice: plot #, yaxis increasing, no axis label
    kargs for imshow keywords (namely cmap='bone')"""
    plt.subplot(1, 3, i)
    plt.imshow(x, origin='lower', **kargs)
    plt.axis('off')

def mkline(x):
    "make a vertical line with bounds of current plot"
    plt.vlines(x, ymin=plt.ylim()[0], ymax=plt.ylim()[1])

def plot_changes():
    "plot with a lot of globals"
    im(1, coronal)
    mkline(neck_at)

    im(2, coronal_mask, cmap='bone')
    mkline(neck_at)
    plt.plot(line_coverage)
    plt.plot(line_smooth)

    center_slice = no_neck[:,int(no_neck.shape[1]/2),:]
    im(3, center_slice, cmap='bone')

    plt.show()

plot_changes()
