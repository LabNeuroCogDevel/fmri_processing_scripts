function P = ZtoP(Z,varargin)
%
% FUNCTION:     ZtoP -- Computes 1 or 2-tailed P values from Z scores generated
%                       using the function RtoZ. Can handle multiple dimensions.
%
% USAGE:        P = ZtoP(Zmat)
%
% Inputs:       Z      -- Z scores generated from RtoZ. Can be multi-dimensional.
%               tail   -- The number of tails to use - either 1 or 2.
%                         [Default = 2].
%
% Outputs:      P      -- 1 or 2 tailed P values (depending on input option).
%
% EXAMPLE:      P = ZtoP(Z, 'tail', 2)
%
% AUTHOR:       Ameera X Patel
%
% CREATED IN:   MATLAB 7.13
%
% REVISION:     3 (19-11-17)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: calccshift.m 3 19-11-2017 BWTv2.0 axpatel

%% Check files/inputs 

fname=mfilename;
if nargin<1
    help(fname); return;
end

if chkninput(nargin,[1,3],nargout,[0,1],fname)>=1
    P=[]; return;
end

DefaultOpts=struct('tail',2);
Opts=parseInOpts(DefaultOpts,varargin);

err=struct();
err(1).inp=chkintype(Z,'double',fname);
err(2).inp=chkintype(Opts.tail,'numeric',fname,{'1','2'});

if sum(cat(1,err.inp))>=1;
    P=[]; return;
end

%% compute P values

P=1-(0.5.*erfc(-abs(Z)./sqrt(2)));

if Opts.tail==2
    P=P.*2;
end

end
