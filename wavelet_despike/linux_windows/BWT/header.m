function [] = header
%                  
% FUNCTION:     header -- Wavelet despiking header function.
%                
% USAGE:        header()
%
% AUTHOR:       Ameera X Patel
% CREATED:      10-01-2014
%   
% CREATED IN:   MATLAB 7.13
%
% REVISION:     8 (06-09-2017)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: header.m 8 06-09-2017 BWTv2.0 axpatel


%% check inputs

fname=mfilename;

if chkninput(nargin,[0,0],nargout,[0,0],fname)>=1;
    return
end

%% header info
cprintf([0.1,0.1,0.7],'\n============================================\n')
cprintf([0.1,0.1,0.7],'         BrainWavelet Toolbox v2.0')
cprintf([0.1,0.1,0.7],'\n============================================\n')
%cprintf([1,0.4,0],'\n------------------------------------------------\n')
%cprintf([1,0.4,0],'************* ')
%cprintf([0.1,0.1,0.7],'BrainWavelet Toolbox ')
%cprintf([1,0.4,0],'*************\n')
%cprintf([1,0.4,0], '------------------------------------------------\n')

cprintf([0,0,0],'\nAuthor: ')
cprintf([0.1,0.1,0.7],'Ameera X Patel, 2017\n')

cprintf([0,0,0], '\nPlease cite:\n')
cprintf([0.1,0.1,0.7],'doi: 10.1016/j.neuroimage.2015.04.052 \n')
cprintf([0.1,0.1,0.7],'doi: 10.1016/j.neuroimage.2014.03.012 \n\n')

cprintf([1,0.4,0],'------------------------------------------------\n\n')
fprintf('\nWavelet Despiking time series \n\n')

end
