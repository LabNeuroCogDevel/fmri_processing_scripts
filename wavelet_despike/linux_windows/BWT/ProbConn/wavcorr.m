function [wcm,ncoef] = wavcorr(ts,varargin)
%
% FUNCTION:     wavcorr  -- Computes biased or unbiased wavelet correlation
%                           matrix for a matrix of time series.
%                            
% USAGE:        [wcm,ncoef] = wavcorr(ts,varargin)
%
% Inputs:       ts       -- Time series on which to compute correlation
%                           matrix. NB. dimensions should be NX x Nts, i.e. 
%                           time series should be represented in columns.
%
%               Additional Input Options:
%               (These must be specific as MATLAB string-value pairs.)
%
%               method   -- 'biased' or 'unbiased'. Value must be a string
%                           containing one of these methods.
%                           [Default='unbiased'].
%               wavelet  -- Wavelet used for wavelet transform. Input must 
%                           be a string containing one of the following:
%                           'd4','d6','d8','d10','d12','d14','d16','d18',
%                           'd20','la8','la10','la12','la14','la16','la18',
%                           'la20','bl14','bl18','bl20','c6','c12','c18',
%                           'c24','haar'. [Default='d4'].
%               boundary -- Boundary condition to apply. Input must be a
%                           string containing one of the following: 
%                           'circular','reflection'.
%                           [Default='reflection'].
%               nscale   -- Method for computing number of scales. Input
%                           must be a string containing one of the
%                           following: 'conservative','liberal'.
%                           [Default: 'conservative'].
%               mincoef  -- Minimum number of coefficients with which to
%                           calculate wavelet correlation.[Default=2].
%               warning  -- Binary flag indicating whether to display
%                           warning messages [1] or not [0]. [Default=1].
% 
% Outputs:      wcm      -- Correlation matrix with dimensions Nts x Nts.
%               ncoef    -- Number of coefficients used to compute
%                           correlation matrix. This will depend on the
%                           method input.
%
% EXAMPLE:      [cmat,ncoef]=wavcorr(tsmat,'warning',1,'method',...
%                               'boundary','reflection')
%
% AUTHOR:       Ameera X Patel
% CREATED:      12-01-2014
%   
% CREATED IN:   MATLAB 7.13
%
% REVISION:     6
%
% COPYRIGHT:    Ameera X Patel (2013, 2014), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v1.0

% ID: wavcorr.m 6 30-01-2014 BWTv1.0 axpatel


%% check nopts / parse extra opts

fname=mfilename;
if nargin<1
    help(fname); return;
end

if chkninput(nargin,[1,13],nargout,[0,2],fname)>=1
    wcm=[]; 
    if nargout==2; ncoef=[]; end
    return;
end
DefaultOpts=struct('wavelet','d4','boundary','periodic','nscale',...
    'conservative','method','unbiased','mincoef',2,'warning',1);
Opts=parseInOpts(DefaultOpts,varargin);

%% check inputs

wavelets={'d4','d6','d8','d10','d12','d14','d16','d18','d20',...
      'la8','la10','la12','la14','la16','la18','la20',...
      'bl14','bl18','bl20','c6','c12','c18','c24','haar'};
boundaries={'periodic','circular','reflection'};
scaleopts={'conservative','liberal'};
corropts={'unbiased','biased'};

[NX,Nts]=size(ts);

err=struct();
err(1).inp=chkintype(ts,'double',fname);
err(2).inp=chkintype(Opts.wavelet,'char',fname,wavelets);
err(3).inp=chkintype(Opts.boundary,'char',fname,boundaries);
err(4).inp=chkintype(Opts.nscale,'char',fname,scaleopts);
err(5).inp=chkintype(Opts.method,'char',fname,corropts);
err(6).inp=chkintype(Opts.mincoef,'numeric',fname,2:NX);
err(7).inp=chkintype(Opts.warning,'numeric',fname,{'0','1'});

if sum(cat(1,err.inp))>=1;
    wcm=[]; 
    if nargout==2; ncoef=[]; end
    return;
end

%% compute scales, do wavelet transform

NJ=modwt_scales(NX,Opts.nscale,Opts.wavelet);
m=modwt(ts,Opts.wavelet,NJ,Opts.boundary,'RetainVJ',1);

if Opts.mincoef==NX
    if Opts.warning==1
        cprintf('_[1,0.5,0]','*** BrainWavelet Warning ***\n');
        cprintf([1,0.5,0],'Specifying a minimum of %s coefficients for\n',...
            num2str(NX));
        cprintf([1,0.5,0],'correlation is equivalent to use of the biased\n')
        cprintf([1,0.5,0],'method. Using ''biased'' method.\n');
    end
    Opts.method='biased';
end

%% biased method or reflection boundary

wcm=zeros(Nts,Nts,NJ);

if strcmpi(Opts.boundary,'reflection') && strcmpi(Opts.method,'biased');
   cprintf([1,0.5,0],'NB. Use of reflection boundary will result\n');
   cprintf([1,0.5,0],'in unbiased correlation estimate. No such thing\n');
   cprintf([1,0.5,0],'as biased estimate for this boundary condition.\n');
end

if strcmpi(Opts.boundary,'reflection');
    for ii=1:NJ
        wcmi=corr(squeeze(m(1:NX,ii,:)));
        wcmi=(wcmi+wcmi')/2;
        wcm(:,:,ii)=wcmi;
    end
    if nargout==2
        ncoef=zeros(1,NJ);
        ncoef(:)=NX;
    end
    return;
end 
    
if strcmpi(Opts.method,'biased');
    for ii=1:NJ
        wcmi=corr(squeeze(m(:,ii,:)));
        wcmi=(wcmi+wcmi')/2;
        wcm(:,:,ii)=wcmi;
    end
    if nargout==2
        ncoef=zeros(1,NJ);
        ncoef(:)=NX;
    end
    return;
end

%% unbiased method

Lj=FiltWidth(Opts.wavelet,NJ);
BInd=BoundInd(Lj,NX,NJ);

null=find(BInd(2,:)>NX-Opts.mincoef);
nullstr=num2str(null);
wcm(:,:,null)=[];

MJ=size(wcm,3);
for i=1:MJ
    wcmi=corr(squeeze(m(BInd(2,i)+1:NX,i,:)));
    wcmi=(wcmi+wcmi')/2;
    wcm(:,:,i)=wcmi;
end

if MJ<NJ
    if Opts.warning==1
        cprintf('_[1,0.5,0]','*** BrainWavelet Warning ***\n');
        cprintf([1,0.5,0],'All coefficients in scale(s) %s are affected\n',...
            nullstr);
        cprintf([1,0.5,0],'by boundary conditions, or the number of non-\n');
        cprintf([1,0.5,0],'boundary coefficients is < %s. Correlation\n',...
            num2str(Opts.mincoef));
        cprintf([1,0.5,0],'matrix for scale(s) %s not output.\n',nullstr);
    end
end

%% count non-boundary coefficients

if nargout==2
    ncoef=NX-BInd(2,:);
    ncoef(null)=0;
end

end