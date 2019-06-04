function setup
% 
% FUNCTION:		setup -- compiles mex files and adds paths to file
%
% USAGE:        setup
%
% EXAMPLE:      setup
%
% AUTHOR:       Ameera X Patel
% CREATED:      03-02-2014
%
% CREATED IN:   MATLAB 7.13
%
% REVISION:     5 (21-11-2017)
%
% COPYRIGHT:    Ameera X Patel (2017), University of Cambridge
%
% TOOLBOX:      BrainWavelet Toolbox v2.0

% ID: setup.m 5 21-11-2017 BWTv2.0 axpatel

%% add paths and compile mex files

[bwpath,x1,x2] = fileparts(mfilename('fullpath'));

addpath([bwpath filesep 'BWT']);
addpath([bwpath filesep 'third_party/cprintf']);
addpath([bwpath filesep 'third_party/NIfTI']);
addpath([bwpath filesep 'third_party/wmtsa/dwt']);
addpath([bwpath filesep 'third_party/wmtsa/utils']);
addpath([bwpath filesep 'BWT/ProbConn']);

basedir=pwd;

cd([bwpath filesep 'third_party/wmtsa/dwt']);

fprintf('\nCompiling...');

mex('modwtj.c');
mex('imodwtj.c');

if not(isempty(which('modwtj'))) && not(isempty(which('imodwtj')))
	fprintf('\nInstallation complete\n');
end

cd(basedir)

clear bwpath x1 x2 basedir

end
