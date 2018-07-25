function EDOF = edof(m,mmcsi,ind,varargin)
%
% FUNCTION:     edof   -- Finds biased or unbiased estimate of effective
%                         degrees of freedom remaining after wavelet 
%                         despiking.
%                            
% USAGE:        EDOF = edof(mmcsi,ind,varargin)
%
% Inputs:       m      -- Original MODWT decomposition of times series
%                         matrix (dimensions NX x Nts). m must have 
%                         dimensions NX x NJ x Nts.
%               mmcsi  -- Binary matrix with dimensions NX x NJ x Nts. 1
%                         indicates coefficients that were not denoised.
%               ind    -- Indices of boundary coefficients. ind must be a
%                         matrix of dimension 2 x NJ. The 2 rows contain 
%                         start and end indices of boundary coefficients.
%
%               Additional Input Options:
%               (These must be specified as MATLAB string-value pairs).
%
%               method   -- 'biased' or 'unbiased'. Value must be a string
%                           containing one of these methods. The Method must
%                           be input as a MATLAB name-value pair.
%                           [Default='unbiased']
%				boundary -- Wavelet boundary condition used to despike
%							time series
%
% Output:       EDOF   -- Matrix of dimensions NJ x Nts containing the
%                         number of effective degrees of freedom remaining 
%                         after wavelet despiking at each scale, for each 
%                         time series in the input matrix.
%
% EXAMPLE:      EDOF = edof(mmcsi,indices,'method','unbiased')
%
% AUTHOR:       Ameera X Patel
% CREATED:      11-01-2014
%   
% CREATED IN:   MATLAB 7.13
%
% REVISION:     6 (19-11-2017)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: edof.m 6 19-11-2017 BWTv2.0 axpatel


%% parse extra opts

fname=mfilename;
if nargin<1
    help(fname); return;
end

DefaultOpts=struct('method','unbiased','boundary','reflection');
Opts=parseInOpts(DefaultOpts,varargin);

%% check inputs

err=struct();
err(1).inp=chkninput(nargin,[3,7],nargout,[0,1],fname);
err(2).inp=chkintype(mmcsi,'double',fname);
err(3).inp=chkintype(Opts.method,'char',fname,{'biased','unbiased'});
err(4).inp=chkintype(Opts.boundary,'char',fname,...
    {'periodic','circular','reflection'});

if strcmpi(Opts.method,'unbiased') && ~exist('ind','var')
    cprintf('_err','*** BrainWavelet Error ***\n')
    cprintf('err','Please specify index of boundary coefficients for\n');
    cprintf('err','unbiased estimate of degrees of freedom. See\n');
    cprintf('err','BoundInd.m for more information\n');
    return;
end

if exist('ind','var')
    err(5).inp=chkintype(ind,'double',fname);
else
    err(5).inp=0;
end

if sum(cat(1,err.inp))>=1
    EDOF=[]; return;
end

%% biased method (circular) or unbiased (reflection)

NJ=size(mmcsi,2);
sf=2.^(1:NJ);

if strcmpi(Opts.boundary,'reflection')
    Nj=squeeze(sum(mmcsi,1))/2;
    EDOF=max(floor(bsxfun(@rdivide,Nj,sf(:))),1);
    EDOF(:,sum(sum(m,2),1)==0)=0;
    return;
end
    
if strcmpi(Opts.method,'biased')
    Nj=squeeze(sum(mmcsi,1));
    EDOF=max(floor(bsxfun(@rdivide,Nj,sf(:))),1);
    EDOF(:,sum(sum(m,2),1)==0)=0;
    return;
end

%% get/check matrix dimensions

indDim=size(ind);

if not(any(indDim==NJ) || any(indDim==2))
    cprintf('_err','*** BrainWavelet Error ***\n')
    cprintf('err','Matrix dimension mismatch. Please ensure that the\n');
    cprintf('err','input binary matrix has dimensions NX x NJ x Nts\n');
    cprintf('err','and that the boundary indices have dimensions 2 x NJ\n');
    return;
end

if indDim(1)~=2; ind=ind'; end

%% unbiased method

for ii=1:NJ
    mmcsi(ind(1,ii):ind(2,ii),ii,:)=0;
end

Mj=squeeze(sum(mmcsi,1));
EDOF=max(floor(bsxfun(@rdivide,Mj,sf(:))),1);
EDOF(:,sum(sum(m,2),1)==0)=0;

end
