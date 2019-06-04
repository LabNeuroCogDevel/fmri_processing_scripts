function dfPair = MinPairEDOF(dfMat)
%
% FUNCTION:     MinPairEDOF -- Computes edge df values from a matrix of
%                              regions or voxels by scales. Orientation
%                              of matrix does not matter.
%
% USAGE:        dfPair = MinPairEDOF(dfMat)
%
% Input:        dfmat  -- Matrix of regional or voxel df values x scales.
%                         E.g. a matrix of 10,000 voxels x 7 scales.
%
% Output:       dfPair -- Edge df values constructed from the nodal or voxel
%                         df values.
%
% EXAMPLE:      edgeEDOF = MinPairEDOF(dfmat);
%
% AUTHOR:       Ameera X Patel
%
% CREATED IN:   MATLAB 7.13
%
% REVISION:     4 (19-11-17)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: calccshift.m 4 19-11-2017 BWTv2.0 axpatel


[Nsc,N]=size(dfMat);
if Nsc>N 
   dfMat=dfMat';
   [Nsc,N]=size(dfMat);
end

dfRep=NaN(N,N,2);
dfPair=NaN(N,N,Nsc);

for ii=1:Nsc
    dfRep(:,:,1)=repmat(dfMat(ii,:),N,1);
    dfRep(:,:,2)=dfRep(:,:,1)';
    dfPair(:,:,ii)=min(dfRep(:,:,1),dfRep(:,:,2));
end

end
