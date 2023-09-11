% Script for pre-generating stim list for intraop session of Speech Motor Sequence Learning (no-learning version)
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
cfg.SESSION_LABEL = 'nolearning_intraop'; %type of session ('test', 'training', 'preop', 'intraop', 'nolearning_preop', 'nolearning_intraop')
if ~isfield(cfg,'SUBJECT')
  cfg.SUBJECT = ''; %subject identifier
  cfg.GROUP_NUM = [];
elseif ~isfield(cfg,'GROUP_NUM')
	cfg.GROUP_NUM = [];
end
cfg.DATA_TYPE = 'task'; %BIDS data type 'beh' for behavioral and task data. 


% Paths and configurations
if any(strcmp({'MSI','DESKTOP-T5P1L4S'}, getenv('COMPUTERNAME'))) %% paths for Andrew Meier test computers
    cfg.PATH_TASK = 'C:\docs\code\matlab\Task_SpeechMotorSequenceLearning';
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
cfg.N_GROUPS = 1; % number of unique stimulus groups (subject groups)
    cfg.GROUP_NUM = 1; % subjects are not divided into separate groups in this no-learning task version; all are in 'group 1'
cfg.N_BLOCKS = 3; % 
cfg.stopSignalDelay_ms = [600];

prompt = {'Subject ID [string followed by 4 numbers]',...
          'Session',...
          sprintf('Experiment Phase?\n(3 = No_Learning_Preop, 3.5 = No_Learning_Intraop)'),...
          'Number of blocks',...
          'Stop Signal Delay (ms). [May be vector for Training]'};
dlgtitle = 'Experimenter Input';
dims = [1 50];
default_input = {cfg.SUBJECT,cfg.SESSION_LABEL,'3.5',num2str(cfg.N_BLOCKS),num2str(cfg.stopSignalDelay_ms)};
answer = inputdlg(prompt,dlgtitle,dims,default_input);

cfg.SUBJECT = strtrim(answer{1});
cfg.SESSION_LABEL = strtrim(answer{2});
cfg.EXP_PHASE_NUM = str2double(answer{3});
cfg.N_BLOCKS = str2double(answer{4});
cfg.stopSignalDelay_ms = str2num(answer{5});
switch cfg.EXP_PHASE_NUM %%%% EXP_PHASE = 3 and EXP_PHASE = 3.5 are functionally identical; it is just used to keep track of which phase we are running for later analysis
    case 3
        cfg.EXP_PHASE = 'nolearning_preop'; 
    case 3.5
        cfg.EXP_PHASE = 'nolearning_intraop';
    otherwise
        error('Experiment Phase must be one of: 3 = No_Learning_Preop, 3.5 = No_Learning_Intraop') 
end

% Check if all parameters input into GUI
if size(cfg.SUBJECT,2)==0
    error('Must provide required input parameters');
end

%% Constructing and checking paths

% checking data path
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
cd('./scripts');
trials_spec = stimListRandomizer_DBS(cfg);
writetable(trials_spec,cfg.SPEC_PREMADE_FILENAME,'Delimiter','\t','FileType','text');

fprintf('\n%s \n %s \n', 'randomized stim list saved into: ', cfg.SPEC_PREMADE_FILENAME)

