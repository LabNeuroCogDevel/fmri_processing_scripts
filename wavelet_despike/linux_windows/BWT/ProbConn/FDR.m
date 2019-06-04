function [FDRc,FDRa] = FDR(varargin)
%
% FUNCTION:     FDR -- Computes FDR adjustment/correction on vector / matrix of
%                      P values. Can handle up to 3 dimensions.
%
% USAGE:        [FDRc,FDRa] = FDR(varargin)
%
% Inputs:       input 1            -- P values (maximum 3 dimensions)
%               input 2 (optional) -- FDR significance level to use.
%                                     [Default = 0.05]
%               input 3 (optional) -- String containing one of the following
%                                     options: 'harmonic' or 'unit'.
%                                     Harmonic is a harsher correction.
%                                     [Default: 'harmonic'].
%
% Outputs:      FDRc     -- FDR corrected P values
%               FDRa     -- FDR adjusted P values
%
% EXAMPLE:      [FDRc, FDRa] = FDR(pvals, 0.01, 'harmonic')
%
% AUTHOR:       Ameera X Patel
%
% CREATED IN:   MATLAB 7.13
%
% REVISION:     5 (19-11-17)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: calccshift.m 5 19-11-2017 BWTv2.0 axpatel

%% check inputs

fname=mfilename;

err=struct();
err(1).inp=chkninput(nargin,[0,3],nargout,[0,3],fname);

switch nargin,
    case 0,
        help(fname); return
    case 1,
        p=varargin{1};
        q=0.05;
        method='unit';
    case 2,
        p=varargin{1};
        q=varargin{2};
        method='unit';
    case 3,
        p=varargin{1};
        q=varargin{2};
        method=varargin{3};
end

err(2).inp=chkintype(p,'numeric',fname);
err(3).inp=chkintype(q,'numeric',fname);
err(4).inp=chkintype(method,'char',fname,{'harmonic','unit'});

if sum(cat(1,err.inp))>=1
	Thr=[];
    if nargout==2; FDRc=[]; end; 
    if nargout==3; FDRc=[]; FDRa=[]; end; 
    return;
end

%% parse input into vector

Np=size(p);
Ndim=length(Np);
if Ndim>3;
    cprintf('_err','*** BrainWavelet Error ***\n');
    cprintf('err','Too many dimensions in p value input.\n\n');
    return;
end

if Ndim==3;
    p=reshape(p,Np(1)*Np(2)*Np(3),1);
elseif Ndim==2;
    p=reshape(p,Np(1)*Np(2),1);
end

%% check p and q vals are ok

if min(p)<0 || max(p)>1,
    cprintf('_err','*** BrainWavelet Error ***\n');
    cprintf('err','p values must be in range 0 to 1.\n\n');
    return;
end

if max(size(q))>1
    cprintf('_err','*** BrainWavelet Error ***\n');
    cprintf('err','q value must be a single integer in range 0 to 1.\n\n');
    return;
elseif q<0 || q>1
    cprintf('_err','*** BrainWavelet Error ***\n');
    cprintf('err','q value must be in range 0 to 1.\n\n');
    return;
end

%% sort p values and compute cV

[p,pInd]=sort(p);
N=length(p);
Ind=reshape((1:N),N,1);

if strcmpi(method,'unit')
    cV=1;
elseif strcmpi(method,'harmonic')
    cV=sum(1./(1:N));
end

ThrVec=Ind*q/(N*cV);
Thr=max(p(p<=ThrVec));

if Thr==0,
   Thr=max(ThrVec(p<=ThrVec));
elseif isempty(Thr)
   Thr=0;
end

%% compute FDRc

FDRc=p.*N.*cV./Ind;
[psort,pIndR] = sort(pInd);
FDRc=FDRc(pIndR);

%% compute FDRa

FDRa=zeros(N,1);
pprev=1;
for ii=N:-1:1,
    FDRa(ii) = min(pprev,p(ii)*N*cV/ii);
    pprev=FDRa(ii);
end
FDRa=FDRa(pIndR);

%% reshape FDR into original dimensions

FDRc=reshape(FDRc,Np);
FDRa=reshape(FDRa,Np);

end
