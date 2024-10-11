% Launcher script for intraop session of Speech Motor Sequence Learning Task (no-learning version)
% Creating configuration structure

% subject and session
cfg.SESSION_LABEL = 'EMU'; %type of session ('test', 'training', 'preop', 'intraop', 'nolearning_preop', 'nolearning_intraop')
if ~isfield(cfg,'SUBJECT')
  cfg.SUBJECT = ''; %subject identifier
  cfg.GROUP_NUM = [];
elseif ~isfield(cfg,'GROUP_NUM')
	cfg.GROUP_NUM = [];
end
cfg.DATA_TYPE = 'task'; %BIDS data type 'beh' for behavioral and task data. 

% rectangle for photodiodo synchronization
cfg.SCREEN_SYNC_RECT = [0 0 40 40]; %rectangle used for screen sync
cfg.SCREEN_SYNC_COLOR = [255 255 255];

% Paths and PTB configuration on task computer
[~, userdir] = system('echo %USERPROFILE%');
userdir = strtrim(userdir);
cfg.PATH_TASK = [userdir '\Desktop\BML\Task_SpeechMotorSequenceLearning'];
cfg.PATH_SOURCEDATA = [userdir '\Desktop\BML\Data_SpeechMotorSequenceLearning']; %rawdata root folder
cfg.SCREEN_ID = 0; % preferred scree

cfg.AUDIO_ID_PLAYBACK = []; % playback device index; leave blank for default
cfg.AUDIO_ID_RECORDING = []; % playback device index (for voice detection only); leave blank for default

cfg.AUDIO_AMP = 1; %Audio amplitude in linear scale
cfg.SYNC_BEEPS = 0; %initialization beeps for synchronization purposes
cfg.KEYBOARD_ID = []; % prefered keyboard 
cfg.SKIP_SYNC_TEST = 1; %should screen test be skipped (use only for debugging)
cfg.CONSERVE_VRAM_MODE = []; %kPsychUseBeampositionQueryWorkaround


%% Task parameters
cfg.TASK = 'SMSL'; % name of current task
cfg.TASK_VERSION = 5; % version number for task
cfg.TASK_FUNCTION = './scripts/task_smsl.m';
cfg.N_GROUPS = 1; % number of unique stimulus groups (subject groups)
cfg.GROUP_NUM = 1; % subjects are not divided into separate groups in this no-learning task version; all are in 'group 1'
cfg.N_BLOCKS = 3; % 
cfg.stopSignalDelay_ms = [600];
cfg.voiceTriggeredStopSignal = 0; % if true, measure latency of STOP onset from voice onset; if false, measure STOP latency from GO signal
cfg.GoBeepAmp = 0.3;
cfg.StopBeepAmp = 0.2;

prompt = {'Subject ID [string followed by 4 numbers]',...
          'Session',...
          'Run (leave empty for new run)',...
          sprintf('Experiment Phase?\n(3 = No_Learning_EMU1, 3.5 = No_Learning_EMU2)'),...
          'Number of blocks',...
          'Stop Signal Delay (ms). [May be vector for Training]'};
dlgtitle = 'Experimenter Input';
dims = [1 50];
default_input = {cfg.SUBJECT,cfg.SESSION_LABEL,'','3.5',num2str(cfg.N_BLOCKS),num2str(cfg.stopSignalDelay_ms)};
answer = inputdlg(prompt,dlgtitle,dims,default_input);

cfg.SUBJECT = strtrim(answer{1});
cfg.SESSION_LABEL = strtrim(answer{2});
cfg.RUN_ID = str2double(answer{3});
cfg.EXP_PHASE_NUM = str2double(answer{4});
cfg.N_BLOCKS = str2double(answer{5});
cfg.stopSignalDelay_ms = str2num(answer{6});
switch cfg.EXP_PHASE_NUM
    case 3
        cfg.EXP_PHASE = 'nolearning_EMU1'; 
    case 3.5
        cfg.EXP_PHASE = 'nolearning_EMU2';
    otherwise
        error('Experiment Phase must be one of: 3 = No_Learning_EMU1, 3.5 = No_Learning_EMU2') 
end

% Check if all parameters input into GUI
if size(cfg.SUBJECT,2)==0
    error('Must provide required input parameters');
end

%% Initializing cleanup hooks
onCleanupTasks = cell(10,1); 

%% Warnings
warning('on','all'); %enabling warnings
beep off

%% Constructing and checking paths and getting next trial run id

% checking data path
pathSub = [cfg.PATH_SOURCEDATA filesep 'sub-' cfg.SUBJECT];
pathSubSes = [pathSub filesep 'ses-' cfg.SESSION_LABEL];
pathSubSesDataType = [pathSubSes filesep cfg.DATA_TYPE];
pathSubSesAudio = [pathSubSes filesep 'audio'];
cfg.PATH_AUDIO = pathSubSesAudio;

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
if ~isfolder(pathSubSesAudio)
    fprintf('Creating session folder %s \n',pathSubSesAudio)
    mkdir(pathSubSesAudio)
end

% creating files basename 
fileBaseName = ['sub-' cfg.SUBJECT '_ses-' cfg.SESSION_LABEL '_task-' cfg.TASK '_run-'];

%checking for previous runs based PBT events file
if ismissing(cfg.RUN_ID)
  allEventFiles = dir([pathSubSesDataType filesep fileBaseName '*_events.tsv']);
  if ~isempty(allEventFiles)
      prevRunIds = regexp({allEventFiles.name}, '_run-(\d+)_' ,'tokens','ignorecase','forceCellOutput','once');
      prevRunIds = cellfun(@(x) str2double(x{1,1}),prevRunIds,'UniformOutput',true);
      runId = max(prevRunIds) + 1;
  else
      runId = 1;
  end
  cfg.RUN_ID = runId;
end
cfg.PATH_LOG = pathSubSesDataType;
cfg.BASE_NAME = [fileBaseName num2str(cfg.RUN_ID,'%02.f') '_'];
cfg.LOG_FILENAME = [cfg.PATH_LOG filesep cfg.BASE_NAME 'log.txt'];
cfg.EVENT_FILENAME = [cfg.PATH_LOG filesep cfg.BASE_NAME 'events.tsv'];
cfg.TRIAL_FILENAME = [cfg.PATH_LOG filesep cfg.BASE_NAME 'trials-' cfg.EXP_PHASE '.tsv']; %randomized trials info
cfg.SPEC_FILENAME = [cfg.PATH_LOG filesep cfg.BASE_NAME 'spec-' cfg.EXP_PHASE '.tsv']; %randomized trials info

% look for a premade stim order file under the following filename; if not present, run the stim randomizer and make a new stim order
cfg.SPEC_PREMADE_FILENAME = [cfg.PATH_LOG filesep 'sub-' cfg.SUBJECT '_ses-' cfg.SESSION_LABEL '_task-' cfg.TASK '_spec-prepared-' cfg.EXP_PHASE '.tsv'];

%% Starting diary
%open diary for this run (saves PTB initialization output)
diary(cfg.LOG_FILENAME);
onCleanupTasks{10} = onCleanup(@() diary('off'));
fprintf('\nConfiuration struture:\n');
disp(cfg)

%% Start audio recording
onCleanupTasks{6} = Task_BML_InitilizeAudioRecordings(cfg);

%% Saving task function in log folder for documentation
task_function = [pwd filesep cfg.TASK_FUNCTION];
if ~isfile(task_function)
    clear onCleanupTasks
    error('%s.m should be in current working directory',cfg.TASK_FUNCTION);
end
copyfile(task_function,[cfg.PATH_LOG filesep cfg.BASE_NAME 'script.m']);

%% changing to scripts folder
cd('./scripts');

%% Initializing trigger port 
cfg.DIGOUT = [];
if exist('io64','file')==3 || exist('io64','file')==2
  clear('KbWait','PsychHID','KbCheck','Screen');
  cfg.DIGOUT = Setup_DAQ_Stim(cfg.DIGOUT);
  
  % Send initial trigger.
  StimTrigCode = 64;
  io64(cfg.DIGOUT.portObj,cfg.DIGOUT.portAddress,StimTrigCode);
  WaitSecs(0.5);
  io64(cfg.DIGOUT.portObj,cfg.DIGOUT.portAddress,0);
end

%% Launching the task
commandwindow
try
  task_smsl(cfg);
catch e
  fprintf('The identifier was:\n%s',e.identifier);
  fprintf('There was an error! The message was:\n%s',e.message);
end

%% Cleaning up
clear onCleanupTasks