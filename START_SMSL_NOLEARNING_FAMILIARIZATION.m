% Launcher script for preop session of Speech Motor Sequence Learning Task (no-learning version, familiarization phase)
% Creating configuration structure

% subject and session
cfg.SESSION_LABEL = 'SMSL'; 
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
cfg.PATH_SOURCEDATA = [userdir '\Desktop\sourcedata']; %rawdata root folder
cfg.SCREEN_ID = 0; % preferred scree

cfg.AUDIO_ID_PLAYBACK = []; % playback device index; leave blank for default
cfg.AUDIO_ID_RECORDING = []; % playback device index (for voice detection only); leave blank for default

cfg.AUDIO_AMP = 1; %Audio amplitude in linear scale
cfg.SYNC_BEEPS = 1; %initialization beeps for synchronization purposes
cfg.KEYBOARD_ID = []; % prefered keyboard 
cfg.SKIP_SYNC_TEST = 1; %should screen test be skipped (use only for debugging)
cfg.CONSERVE_VRAM_MODE = []; %kPsychUseBeampositionQueryWorkaround

%% Task parameters
cfg.TASK = 'SMSL'; % name of current task
cfg.TASK_VERSION = 5; % version number for task
cfg.TASK_FUNCTION = './scripts/task_smsl.m';
cfg.N_GROUPS = 1; % number of unique stimulus groups (subject groups)
    cfg.GROUP_NUM = 1; % subjects are not divided into separate groups in this no-learning task version; all are in 'group 1'
cfg.N_BLOCKS = 1; % 
cfg.stopSignalDelay_ms = [600];
cfg.voiceTriggeredStopSignal = 0; % if true, measure latency of STOP onset from voice onset; if false, measure STOP latency from GO signal
cfg.GoBeepAmp = 0.5;
cfg.StopBeepAmp = 0.2;

prompt = {'Subject ID [string followed by 4 numbers]',...
          'Session',...
          'Run (leave empty for new run)',...
          sprintf('Experiment Phase?\n(2.5 = No_Learning_Familiarization, 3 = No_Learning_Preop, 3.5 = No_Learning_Intraop)'),...
          'Number of blocks',...
          'Stop Signal Delay (ms). [May be vector for Training]'};
dlgtitle = 'Experimenter Input';
dims = [1 50];
default_input = {cfg.SUBJECT,cfg.SESSION_LABEL,'','2.5',num2str(cfg.N_BLOCKS),num2str(cfg.stopSignalDelay_ms)};
answer = inputdlg(prompt,dlgtitle,dims,default_input);

cfg.SUBJECT = strtrim(answer{1});
cfg.SESSION_LABEL = strtrim(answer{2});
cfg.RUN_ID = str2double(answer{3});
cfg.EXP_PHASE_NUM = str2double(answer{4});
cfg.N_BLOCKS = str2double(answer{5});
cfg.stopSignalDelay_ms = str2num(answer{6});
switch cfg.EXP_PHASE_NUM
    case 2.5
        cfg.EXP_PHASE = 'nolearning_familiarization'; 
    case 3
        cfg.EXP_PHASE = 'nolearning_preop'; 
    case 3.5
        cfg.EXP_PHASE = 'nolearning_intraop';
    otherwise
        error('Experiment Phase must be one of: 2.5 = No_Learning_Familiarization, 3 = No_Learning_Preop, 3.5 = No_Learning_Intraop') 
end

% Check if all parameters input into GUI
if size(cfg.SUBJECT,2)==0
    error('Must provide required input parameters');
end

%% Initializing
cfg.onCleanupTasks = cell(10,1); 
cfg = Task_BML_InitializePaths(cfg);
cfg = Task_BML_InitializeDiary(cfg);
cfg = Task_BML_InitilizeAudioRecordings(cfg);
cfg = Task_BML_InitializeEvents(cfg);
cfg = Task_BML_logMetadata(cfg);
cfg = Task_BML_DocumentTaskFunction(cfg);

% look for a premade stim order file under the following filename; if not present, run the stim randomizer and make a new stim order
cfg.SPEC_PREMADE_FILENAME = [cfg.PATH_LOG filesep 'sub-' cfg.SUBJECT '_ses-' cfg.SESSION_LABEL '_task-' cfg.TASK '_spec-prepared-' cfg.EXP_PHASE '.tsv'];

%% changing to scripts folder
cd('./scripts');

%% Launching the task
commandwindow
try
  task_smsl(cfg);
catch e
	fprintf('The identifier was:\n%s',e.identifier);
	fprintf('There was an error! The message was:\n%s',e.message);
end

%% Cleaning up
fprintf('\nCleaning up...\n');
cfg.onCleanupTasks = [];
WaitSecs(2);
fprintf('Done!\n');

