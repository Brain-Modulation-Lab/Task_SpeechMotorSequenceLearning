% Script for pre-generating stim list for pre-op session of Speech Motor Sequence Learning
% Because stim randomization can sometimes take a few minutes, this script will enable you to create a stimlist...
%   .... in advance of starting the session
%
% Running this script will create a stim list file in the sourcedata-task directory
% When a START_SMSL_ script is run, it will look for this saved stim list and load it....
%   .... instead of creating a new stim list order
%
% Instead of creating a randomized stim list for each run within a subject/session/phase, we will premake one list....
%     .... and load it for all runs in this subject/session/phase

clear

% subject and session
cfg.SESSION_LABEL = 'preop'; %type of session ('test', 'training', 'preop', 'intraop')
if ~isfield(cfg,'SUBJECT')
  cfg.SUBJECT = ''; %subject identifier
  cfg.GROUP_NUM = [];
elseif ~isfield(cfg,'GROUP_NUM')
	cfg.GROUP_NUM = [];
end
cfg.DATA_TYPE = 'task'; %BIDS data type 'beh' for behavioral and task data. 


% Paths and configurations
if any(strcmp({'MSI','DESKTOP-T5P1L4S'}, getenv('COMPUTERNAME'))) %% paths for Andrew Meier test computers
    cfg.PATH_TASK = 'C:\docs\code\matlab\packages\Task_SpeechMotorSequenceLearning';
    cfg.PATH_SOURCEDATA = 'C:\docs\code\matlab\DBS\sourcedata'; %source data root folder 
elseif strcmp('BML-ALIENWARE', getenv('COMPUTERNAME'))
    cfg.PATH_TASK = 'D:\Task\Task_SpeechMotorSequenceLearning';
    cfg.PATH_SOURCEDATA = 'D:\DBS\sourcedata'; %sourcedata root folder 
elseif strcmp('BML-ALIENWARE2', getenv('COMPUTERNAME'))
    cfg.PATH_TASK = 'D:\Task\Task_SpeechMotorSequenceLearning';
    cfg.PATH_SOURCEDATA = 'D:\DBS\sourcedata'; %sourcedata root folder 

else
    cfg.PATH_TASK = '~/git/Task_SpeechMotorSequenceLearning'; 
    cfg.PATH_SOURCEDATA = '~/Data/DBS/sourcedata'; %source data root folder 
end


%% Task parameters
cfg.TASK = 'SMSL'; % name of current task
cfg.N_GROUPS = 7; % number of unique stimulus groups (subject groups)
cfg.N_BLOCKS = 1; % changed from 2 to 1, because the 'preop' session is 10min rather than 5min
cfg.stopSignalDelay_ms = [600];

prompt = {'Subject ID [string followed by 4 numbers]',...
          'Session',...
          'Group Number (1-7)',...
          sprintf('Experiment Phase?\n(0 = Familiarization, 1 = Training, 1.5 = Preop, 2 = Testing)'),...
          'Number of blocks',...
          'Stop Signal Delay (ms). [May be vector for Training]'};
dlgtitle = 'Experimenter Input';
dims = [1 50];
definput = {cfg.SUBJECT,cfg.SESSION_LABEL,num2str(cfg.GROUP_NUM),'1.5',num2str(cfg.N_BLOCKS),num2str(cfg.stopSignalDelay_ms)};
answer = inputdlg(prompt,dlgtitle,dims,definput);

cfg.SUBJECT = strtrim(answer{1});
cfg.SESSION_LABEL = strtrim(answer{2});
cfg.GROUP_NUM = str2double(answer{3});
cfg.EXP_PHASE_NUM = str2double(answer{4});
cfg.N_BLOCKS = str2double(answer{5});
cfg.stopSignalDelay_ms = str2num(answer{6});
switch cfg.EXP_PHASE_NUM
    case 0
        cfg.EXP_PHASE = 'Familiarization';
    case 1
        cfg.EXP_PHASE = 'Training';
    case 1.5
        cfg.EXP_PHASE = 'Preop'; 
    case 2
        cfg.EXP_PHASE = 'Test';
    otherwise
        error('Experiment Phase must be one of: 0 = Familiarization, 1 = Training, 1.5 = Preop, 2 = Testing') 
end

% Check if all parameters input into GUI
if size(cfg.SUBJECT,2)==0
    error('Must provide required input parameters');
elseif size(cfg.GROUP_NUM,2)==0
    error('Must provide required input parameters');
end

try
    foo = cfg.GROUP_NUM < 1;
catch
    error('group number must be integer');
end

%Test for groupNum in appropriate range
if (cfg.GROUP_NUM > cfg.N_GROUPS) || (cfg.GROUP_NUM < 1) 
    error (['group number must be between 1 and ', num2str(cfg.N_GROUPS)])
end

%% Constructing and checking paths

%checking data path
pathSub = [cfg.PATH_SOURCEDATA filesep 'sub-' cfg.SUBJECT];
pathSubSes = [pathSub filesep 'ses-' cfg.SESSION_LABEL];
pathSubSesDataType = [pathSubSes filesep cfg.DATA_TYPE];
if ~isfolder(cfg.PATH_SOURCEDATA)
    error('rawdata folder %s does not exist',cfg.PATH_SOURCEDATA)
end
if ~isfolder(pathSub)
    fprintf('Creating subject folder %s \n',pathSub)
    mkdir(pathSub)
end
if ~isfolder(pathSubSes)
    fprintf('Creating session folder %s \n',pathSubSes)
    mkdir(pathSubSes)
end
if ~isfolder(pathSubSesDataType)
    fprintf('Creating session folder %s \n',pathSubSesDataType)
    mkdir(pathSubSesDataType)
end

% creating filename for saving stimlist 
%%% do not include run number, because this file will be used for all runs in this subject/session/phase
cfg.BASE_NAME = ['sub-' cfg.SUBJECT '_ses-' cfg.SESSION_LABEL '_task-' cfg.TASK '_spec-prepared-' cfg.EXP_PHASE '.tsv'];
cfg.PATH_LOG = pathSubSesDataType;
cfg.SPEC_PREMADE_FILENAME = [cfg.PATH_LOG filesep cfg.BASE_NAME ]; % filename containing pre-made trials spec to load

disp(cfg)

%% run randomizer and save output
fprintf('\n running stim list randomizer...')

cfg.load_premade_specfile = 0; 
cd('.\scripts')
trials_spec = stimListRandomizer_DBS(cfg);
writetable(trials_spec,cfg.SPEC_PREMADE_FILENAME,'Delimiter','\t','FileType','text');

fprintf('\n%s \n %s \n', 'randomized stim list saved into: ', cfg.SPEC_PREMADE_FILENAME)

