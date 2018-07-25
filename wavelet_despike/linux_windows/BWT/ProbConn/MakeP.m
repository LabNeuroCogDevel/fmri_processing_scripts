function [varargout] = MakeP(ts,EDOF)
%
% FUNCTION:     MakeP -- Script for converting time series and regional EDOF
%                        estimates into wavelet correlation (R) and FDR-adjusted
%                        P value matrices.
%
% USAGE:        [varargout] = MakeP(ts,EDOF)
%
% Inputs:       ts    -- matrix of time series (represented in columns), i.e. voxel
%                        or region is represented in columns, and time in rows.
%               EDOF  -- matrix of EDOF estimates, where voxel or region is represented
%                        in columns, and wavelet scale (j) in rows.
%
% Outputs:      All outputs are optional. If no output is specified, the script will
%               write the FDR-ajusted P matrices and correlation (R) matrices to the
%               working directory in the form FDR_j.txt and R_j.txt where j is the
%               number of the wavelet scale.
%
%               output 1 -- FDR adjusted P values matrices of size roi x roi x scale.
%               output 2 -- Wavelet correlation matrices of size roi x roi x scale.
%
% EXAMPLES:      [FDRa, R] = MakeP(timeseries, dfseries)
%               [] = MakeP(timeseries, dfseries)
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

%% load workspace variables

ts=load(ts);
EDOF=load(EDOF);

%p_err=load(p_err);
%ts(:,p_err)=[];
%EDOF(:,p_err)=[];

%% compute wavelet correlations / edge df

wc=wavcorr(ts,'boundary','reflection');

EDOFpair=MinPairEDOF(EDOF);

%% calculate FDR adjusted P vals.

wcs=size(wc);
R=zeros(wcs);
Z=zeros(wcs);
P=zeros(wcs);
FDRadj=zeros(wcs);

for ii=1:wcs(3)
    dlmwrite(sprintf('R_%s.txt',num2str(ii)),wc(:,:,ii),' ');
end

for i=1:wcs(3)
    R(:,:,i)=wc(:,:,i);
    Z(:,:,i)=RtoZ(R(:,:,i),EDOFpair(:,:,i));
    P(:,:,i)=ZtoP(Z(:,:,i));
    Pval=P(:,:,i);
    ValInds=find(~tril(ones(size(Pval))));
    Pval=Pval(ValInds);
    [x1,x2,FDRa]=FDR(Pval,0.01,'harmonic');
    FDRaM=zeros(wcs(1),wcs(2));
    FDRaM(ValInds)=FDRa;
    FDRaM=FDRaM+FDRaM';
    FDRaM(1:1+wcs(2):end)=1;
    FDRadj(:,:,i)=FDRaM;
end

% convert zero P values to 1/(10^100) in order for these edges to be
% inluded in graphs.

FDRadj(FDRadj==0)=1/(10^100);

%% Output variables to workding dir or workspace

if nargout==1;
   varargout{1}=FDRadj;
   varargout{2}=R;
   return;
elseif nargout==0;
    fprintf('Writing variables to directory as FDR_n.txt and R_n.txt\n')
    for ii=1:wcs(3)
        dlmwrite(sprintf('FDR_%s.txt',num2str(ii)),FDRadj(:,:,ii),' ');
        dlmwrite(sprintf('R_%s.txt',num2str(ii)),R(:,:,ii),' ');
    end
end
end
