function [] = WaveletDespike(Inii,Opref,varargin)
%
% FUNCTION:     WaveletDespike -- Wavelet despikes time series, and outputs
%                                 effective df as described in:
%
% Patel, AX. et al (2014). A wavelet method for modeling and despiking
% motion artifacts from resting-state fMRI time serires. NeuroImage.
% 95: 287-304.
%
% Patel, AX. and Bullmore, ET. (2016). A wavelet-based estimator of the
% degrees of freedom in denoised fMRI time series for probabilistic
% testing of functional connectivity and brain graphs. NeuroImage.
% 142: 14-26.
%
% USAGE:        WaveletDespike(Inii,Opref,varargin)
%
% Inputs:       Inii      -- NIfTI file (3D+t dataset) containing time
%                            series to despike.
%               Opref     -- Output prefix for despiked NIfTI files and
%                            Spike Percentage / EDOF (if specified).
%
%               Additional Input Options:
%               (These must be specified as MATLAB string-value pairs.)
%
%               wavelet   -- Wavelet to use for wavelet transform. Input
%                            must be a string containing one of the 
%                            following:
%                            'd4','d6','d8','d10','d12','d14','d16','d18',
%                            'd20','la8','la10','la12','la14','la16',
%                            'la18','la20','bl14','bl18','bl20','c6','c12',
%                            'c18','c24','haar'. [Default='d4'].
%               threshold -- Threshold for maximal and minimal wavelet
%                            coefficients. [Default=10].
%               boundary  -- Boundary condition to apply. Input must be a
%                            string containing one of the following: 
%                            'circular','reflection'.
%                            [Default='reflection'].
%               chsearch  -- Rules for identifying maxima and minima 
%                            chains. Input must be a string containing one 
%                            of the following: 'conservative', 'moderate',
%                            'harsh'. [Default='moderate'].
%               nscale    -- Method for computing number of scales. Input
%                            must be a string containing one of the
%                            following: 'conservative','liberal','extreme'
%                            [Default: 'liberal'], or a number between 0
%                            and 1. If a number is specified, the number
%                            of scales used will be a fraction of the
%                            maximum allowed by the 'liberal' method.
%               compress  -- Binary flag indicating whether to compress out
%                            non-brain regions, 1, or not, 0, from input 
%                            NIfTI file before wavelet despiking. This
%                            saves RAM and reduces runtime. [Default=1].
%               SP        -- Binary flag indicating whether to output the
%                            Spike Percentage for the dataset.
%                            [Default=1].
%               EDOF      -- Binary flag indicating whether to output the
%                            effective degrees of freedom maps for the
%                            dataset at each wavelet scale. [Default=1].
%               EDOF_method  Method for calculating effective degrees of
%                            freedom - 'biased' or 'unbiased'. NB biased
%                            method does not apply for reflection boundary
%                            condition. [Default='unbiased'].
%               LimitRAM  -- Specify an upper bound of RAM usage (in Giga-
%                            bytes). Default is to use all available RAM.
%               verbose   -- Binary flag indicating whether to display
%                            incremental output from the algorithm, 1, or
%                            not, 0. [Default=1].
% 
% Outputs:      This function will write the following files to the current
%               directory:
%
%               Opref_wds.nii.gz   - Wavelet despiked time series.
%               Opref_noise.nii.gz - Noise times series removed in wavelet
%                                    despiking.
%               Opref_SP.txt       - The Spike Percentage (if specified at
%                                    input).
%               Opref_EDOF.nii.gz  - Degrees of freedom map for each
%                                    wavelet scale.
%
% EXAMPLE:      WaveletDespike('rest.nii.gz','rest','wavelet','la8',...
%                   'LimitRAM',5)
%
% AUTHOR:       Ameera X Patel
% CREATED:      26-12-2013
%   
% CREATED IN:   MATLAB 7.13
%
% REVISION:     24 (19-11-2017)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: WaveletDespike.m 24 19-11-2017 BWTv2.0 axpatel


%% check nopts / parse extra opts

fname=mfilename;
if nargin<1
   help(fname); return;
end

if chkninput(nargin,[2,30],nargout,[0,0],fname)>=1
   return
end    

DefaultOpts=struct('wavelet','d4','threshold',10,'boundary','reflection',...
    'chsearch','moderate','nscale','liberal','compress',1,'SP',1,...
    'EDOF',1,'EDOF_method','unbiased','LimitRAM',0,'verbose',1,...
    'TimeWindow',0,'TR',0,'window',0);

Opts=parseInOpts(DefaultOpts,varargin);

%% check inputs

wavelets={'d4','d6','d8','d10','d12','d14','d16','d18','d20',...
      'la8','la10','la12','la14','la16','la18','la20',...
      'bl14','bl18','bl20','c6','c12','c18','c24','haar'};
boundaries={'periodic','circular','reflection'};
ok_chtype={'conservative','moderate','harsh'};
scaleopts={'conservative','liberal','extreme'};

err=struct();
err(1).inp=chkintype(Inii,'char',fname);
err(2).inp=chkintype(Opref,'char',fname);
err(3).inp=chkintype(Opts.wavelet,'char',fname,wavelets);
err(4).inp=chkintype(Opts.threshold,'numeric',fname);
err(5).inp=chkintype(Opts.boundary,'char',fname,boundaries);
err(6).inp=chkintype(Opts.chsearch,'char',fname,ok_chtype);
if ~isnumeric(Opts.nscale)
    err(7).inp=chkintype(Opts.nscale,'char',fname,scaleopts);
end
err(8).inp=chkintype(Opts.compress,'numeric',fname,{'0','1'});
err(9).inp=chkintype(Opts.SP,'numeric',fname,{'0','1'});
err(10).inp=chkintype(Opts.EDOF,'numeric',fname,{'0','1'});
err(11).inp=chkintype(Opts.EDOF_method,'char',fname,{'biased','unbiased'});
err(12).inp=chkintype(Opts.LimitRAM,'numeric',fname);
err(13).inp=chkintype(Opts.verbose,'numeric',fname,{'0','1'});
err(14).inp=chkintype(Opts.TimeWindow,'numeric',fname,{'0','1'});
err(15).inp=chkintype(Opts.TR,'numeric',fname);
err(16).inp=chkintype(Opts.window,'numeric',fname);

if sum(cat(1,err.inp))>=1;
   return
end

if Opts.TimeWindow==1 && Opts.TR==0
    cprintf('_err',' \n*** BrainWavelet Error ***\n')
    cprintf('err','TimeWindower: Cannot compute window length\n') 
    cprintf('err','without the TR!\n\n',fname);
    return
end


%% load NIfTI

t=cputime;

[ts,Info,error]=ParseInNii(Inii,'compress',Opts.compress);

if error==1 
    return
end
header;

[NX,NTS]=size(ts);

%% check window size
if Opts.window>NX
    cprintf('_err',' \n*** BrainWavelet Error ***\n')
    cprintf('err','TimeWindower: Your window is longer that the\n') 
    cprintf('err','number of time points!\n\n',fname);
    return
end

%% Parse MemorySolver for BatchMode

if strcmpi(Opts.boundary,'reflection');
    NXref=NX*2;
    [BatchMode,freeRAM]=MemorySolver(NTS,NXref,'LimitRAM',Opts.LimitRAM);
else 
    [BatchMode,freeRAM]=MemorySolver(NTS,NX,'LimitRAM',Opts.LimitRAM);
end

if isempty(BatchMode);
    return; 
end

%% run wavelet despiking in normal mode

if BatchMode==0 && Opts.TimeWindow==0
    if Opts.SP==1 && Opts.EDOF==0
        [clean,noise,SP]=wdscore(ts,'wavelet',Opts.wavelet,'threshold',...
            Opts.threshold,'boundary',Opts.boundary,'chsearch',...
            Opts.chsearch,'nscale',Opts.nscale,'verbose',Opts.verbose);
    elseif Opts.SP==1 && Opts.EDOF==1
        [clean,noise,SP,EDOF]=wdscore(ts,'wavelet',Opts.wavelet,...
            'threshold',Opts.threshold,'boundary',Opts.boundary,...
            'chsearch',Opts.chsearch,'nscale',Opts.nscale,'verbose',...
            Opts.verbose,'EDOF_method',Opts.EDOF_method);
    else
        [clean,noise]=wdscore(ts,'wavelet',Opts.wavelet,'threshold',...
            Opts.threshold,'boundary',Opts.boundary,'chsearch',...
            Opts.chsearch,'nscale',Opts.nscale,'verbose',Opts.verbose);
    end
    
elseif BatchMode==0 && Opts.TimeWindow==1
	[clean,noise,SP,EDOF,TW]=wdscore(ts,'wavelet',Opts.wavelet,...
        'threshold',Opts.threshold,'boundary',Opts.boundary,...
        'chsearch',Opts.chsearch,'nscale',Opts.nscale,'verbose',...
        Opts.verbose,'EDOF_method',Opts.EDOF_method);
end

%% run wavelet despiking in batch mode

if BatchMode>=1
    
    Ind=ParseInds(NTS,BatchMode);
    Batchstr=num2str(BatchMode);
    clean=zeros(NX,NTS);
    noise=zeros(NX,NTS);
    
    fprintf('+ Initialising Batch Mode ...\n')
	
    if Opts.LimitRAM==0
        fprintf('+ Using all available RAM. WARNING: your computer \n')
        fprintf('+ may be slow whilst this program is running.\n')
    else
        fprintf('+ Capping RAM usage at %s Gb ...\n',...
            num2str(freeRAM));
    end
        
    for ii=1:BatchMode
        
        fprintf('\nDespiking batch %s of %s.\n', num2str(ii),...
            Batchstr);
        
        tts=ts(:,Ind(1,ii):Ind(2,ii));
        
        if Opts.TimeWindow==1
            [clean(:,Ind(1,ii):Ind(2,ii)),noise(:,Ind(1,ii):Ind(2,ii)),...
                SP(:,ii),EDOF(:,Ind(1,ii):Ind(2,ii)),...
                TW(:,:,Ind(1,ii):Ind(2,ii))]=wdscore(tts,...
                'wavelet',Opts.wavelet,'threshold',Opts.threshold,...
                'boundary',Opts.boundary,'chsearch',Opts.chsearch,...
                'nscale',Opts.nscale,'EDOF_method',Opts.EDOF_method);
            SP(:,ii)=SP(:,ii).*((Ind(2,ii)-Ind(1,ii)+1)/NTS);
        elseif Opts.SP==1 && Opts.EDOF==0
            [clean(:,Ind(1,ii):Ind(2,ii)),noise(:,Ind(1,ii):Ind(2,ii)),...
                SP(:,ii)]=wdscore(tts,'wavelet',Opts.wavelet,...
                'threshold',Opts.threshold,'boundary',Opts.boundary,...
                'chsearch',Opts.chsearch,'nscale',Opts.nscale,'verbose',...
                Opts.verbose);
            SP(:,ii)=SP(:,ii).*((Ind(2,ii)-Ind(1,ii)+1)/NTS);
        elseif Opts.SP==1 && Opts.EDOF==1
            [clean(:,Ind(1,ii):Ind(2,ii)),noise(:,Ind(1,ii):Ind(2,ii)),...
                SP(:,ii),EDOF(:,Ind(1,ii):Ind(2,ii))]=wdscore(tts,...
                'wavelet',Opts.wavelet,'threshold',Opts.threshold,...
                'boundary',Opts.boundary,'chsearch',Opts.chsearch,...
                'nscale',Opts.nscale,'EDOF_method',Opts.EDOF_method);
            SP(:,ii)=SP(:,ii).*((Ind(2,ii)-Ind(1,ii)+1)/NTS);
        else
            [clean(:,Ind(1,ii):Ind(2,ii)),noise(:,Ind(1,ii):Ind(2,ii))]...
                =wdscore(tts,'wavelet',Opts.wavelet,'threshold',...
                Opts.threshold,'boundary',Opts.boundary,'chsearch',...
                Opts.chsearch,'nscale',Opts.nscale,'verbose',Opts.verbose);
        end     
    end
    
    if exist('SP','var')
        SP=sum(SP,2);
    end
end

%% Write files

WriteOutNii(clean,strcat(Opref,'_wds.nii.gz'),Info);
WriteOutNii(noise,strcat(Opref,'_noise.nii.gz'),Info);

if exist('SP','var')
    dlmwrite(sprintf('%s_SP.txt',Opref),SP,' ');
end

if exist('EDOF','var')
    WriteOutNii(EDOF,strcat(Opref,'_EDOF.nii.gz'),Info);
end

footer(t);

%% Time Windower 
% currently only available for: biased EDOF with periodic boundary or
% unbiased for reflection boundary

if Opts.TimeWindow==1
    if strcmpi(Opts.boundary,'reflection')
        TW=(TW(1:NX,:,:)+flipdim(TW(NX+1:NX*2,:,:),1))/2;
    end
    TW=abs(1-TW);
    fprintf('+ Initialising Time Windower\n++\n')
    if Opts.window==0        
        fprintf('+ Using default initial window length of 50.\n')
        Opts.window=50;
    end
   
    [DynEDOF,OptWindowL]=TimeWindower(TW,Opts.window,Opts.TR);
    nwindows=size(DynEDOF,1);
    maxj=size(DynEDOF,2);
    
    freqs(:,1)=(Opts.TR*2)*(2.^(1:maxj));
    freqs(:,2)=(Opts.TR)*(2.^(1:maxj));
    
    fprintf('\n+ Divided time series into %s windows.\n',num2str(nwindows))
    
    for i=1:maxj
        eval(['W' num2str(i) '=squeeze(DynEDOF(:,i,:));']);
        WriteOutNii(eval(['W' num2str(i)]),strcat(Opref,'_DynEDOF',...
            num2str(i),'.nii.gz'),Info)
        fprintf('+ Frequency range for %s : 1/%s to 1/%s Hz \n',...
            strcat(Opref,'_DynEDOF',num2str(i),'.nii.gz'),...
            num2str(freqs(i,1)),num2str(freqs(i,2)))
    end
    
    WriteOutNii(squeeze(sum(DynEDOF,2)),strcat(Opref,...
        '_DynEDOFsum.nii.gz'),Info);
    fprintf('+ Frequency range for %s : 1/%s to 1/%s Hz \n',...
            strcat(Opref,'_DynEDOFsum.nii.gz'),...
            num2str(max(max(freqs))),num2str(min(min(freqs))));
    
    dlmwrite(sprintf('%s_windowL.txt',Opref),OptWindowL,' ');
    
end

end
