function Mem = FindFreeRAM()
%
% FUNCTION:     FindFreeRAM -- Computes maximum available memory.
%                            
% USAGE:        Mem = FindFreeRAM()
%
% Output:       Mem         -- Outputs free memory in Gigabytes
%
% EXAMPLE:      Memory = FindFreeRAM
%
% AUTHOR:       Ameera X Patel
% CREATED:      22-01-2014
%   
% CREATED IN:   MATLAB 7.13
%
% REVISION:     7 (06-09-2017)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: FindFreeRAM.m 7 06-09-2017 BWTv2.0 axpatel

%% check inputs

fname=mfilename;

if chkninput(nargin,[0,0],nargout,[0,1],fname)>=1
    Mem=[]; return
end

%% detect system and find free memory

if isunix==1 && ismac==0
	[E,Num]=system('free | grep Mem | awk ''{print $3}'' ');
	Mem=str2double(Num);
	Mem=Mem/(2^20);

elseif ispc==1
	[user sys] = memory;
	Mem=user.MemAvailableAllArrays;
	Mem=Mem/(2^30);

else
	cprintf('_err','*** BrainWavelet Error ***\n')
	cprintf('err','You do not appear to be running Linux or Windows.\n')
	cprintf('err','Please download the correct toolbox version from \n')
	cprintf('err','www.brainwavelet.org.\n\n')
	Mem=[];
	end

end
