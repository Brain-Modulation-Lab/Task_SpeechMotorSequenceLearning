% Launcher script for training session of Speech Motor Sequence Learning
% task
% Creating configuration structure

% check protocol
cfg.protocol = 'udp';
% subject and session
%%%% NB: to avoid errors, use subject name that starts with letter and
%%%% ends with 4 numbers
cfg.SESSION_LABEL = 'intraop'; %type of session ('test', 'training', 'preop', 'intraop')
if ~isfield(cfg,'SUBJECT')
  cfg.SUBJECT = ''; %subject identifier
  cfg.GROUP_NUM = [];
elseif ~isfield(cfg,'GROUP_NUM')
	cfg.GROUP_NUM = [];
end
cfg.DATA_TYPE = 'task'; %BIDS data type 'beh' for behavioral and task data. 

% rectangle for photodiodo synchronization
cfg.SCREEN_SYNC_RECT = [0 0 20 20]; %rectangle used for screen sync
cfg.SCREEN_SYNC_COLOR = [255 255 255];


if any(strcmp({'MSI','DESKTOP-T5P1L4S','677-GUE-WL-0010'}, getenv('COMPUTERNAME'))) %% paths for Andrew Meier test computers
    cfg.PATH_TASK = 'C:\docs\code\Task_SpeechMotorSequenceLearning';
    cfg.PATH_SOURCEDATA = 'C:\Users\amsme\Downloads'; %source data root folder 
    cfg.SCREEN_ID = 1; % preferred screen 
elseif strcmpi('BML-ALIENWARE',getenv('COMPUTERNAME'))
    cfg.PATH_TASK = 'D:\Task\Task_SpeechMotorSequenceLearning';
    cfg.PATH_SOURCEDATA = 'D:\DBS\sourcedata'; %source data root folder 
    cfg.SCREEN_ID = 3; % preferred screen 
elseif strcmpi('BML-ALIENWARE2',getenv('COMPUTERNAME'))
    cfg.PATH_TASK = 'D:\Task\Task_SpeechMotorSequenceLearning';
    cfg.PATH_SOURCEDATA = 'D:\DBS\sourcedata'; %source data root folder 
    cfg.SCREEN_ID =2; % preferred screen 
else
    cfg.PATH_TASK = '~/git/Task_SpeechMotorSequenceLearning'; 
    cfg.PATH_SOURCEDATA = '~/Data/DBS/sourcedata'; %source data root folder 
    cfg.SCREEN_ID = 1; % preferred screen 
end

% Paths and configurations
cfg.AUDIO_ID_PLAYBACK = 5; % playback device index; leave blank for default
cfg.AUDIO_ID_RECORDING = []; % playback device index (for voice detection only); leave blank for default

cfg.AUDIO_AMP = 1; %Audio amplitude in linear scale
cfg.SYNC_BEEPS = 1;
cfg.KEYBOARD_ID = []; % prefered keyboard 
cfg.SKIP_SYNC_TEST = 1; %should screen test be skipped (use only for debugging)
cfg.CONSERVE_VRAM_MODE = []; %kPsychUseBeampositionQueryWorkaround

%% Task parameters
cfg.TASK = 'SMSL'; % name of current task
cfg.TASK_VERSION = 4; % version number for task
cfg.TASK_FUNCTION = './scripts/task_smsl.m';
cfg.N_GROUPS = 7; % number of unique stimulus groups (subject groups)
cfg.N_BLOCKS = 3;
cfg.stopSignalDelay_ms = 600;
cfg.voiceTriggeredStopSignal = 0; % if true, measure latency of STOP onset from voice onset; if false, measure STOP latency from GO signal
cfg.loudness_threshold = 0.1; % amplitude threshold for voice detection; range 0 to 1
cfg.GoBeepAmp = 0.3;
cfg.StopBeepAmp = 0.2;


prompt = {'Subject ID [string followed by 4 numbers]',...
          'Session',...
          'Run (leave empty for new run)',...
          'Group Number (1-7)',...
          sprintf('Experiment Phase?\n(0 = Familiarization, 1 = Training, 1.5 = Preop, 2 = Testing)'),...
          'Number of blocks',...
          'Stop Signal Delay (ms). [May be vector for Training]'};
dlgtitle = 'Experimenter Input';
dims = [1 50];
definput = {cfg.SUBJECT,cfg.SESSION_LABEL,'',num2str(cfg.GROUP_NUM),'2',num2str(cfg.N_BLOCKS),num2str(cfg.stopSignalDelay_ms)};
answer = inputdlg(prompt,dlgtitle,dims,definput);

cfg.SUBJECT = strtrim(answer{1});
cfg.SESSION_LABEL = strtrim(answer{2});
cfg.RUN_ID = str2double(answer{3});
cfg.GROUP_NUM = str2double(answer{4});
cfg.EXP_PHASE_NUM = str2double(answer{5});
cfg.N_BLOCKS = str2double(answer{6});
cfg.stopSignalDelay_ms = str2num(answer{7});
switch cfg.EXP_PHASE_NUM
    case 0
        cfg.EXP_PHASE = 'Familiarization';
    case 1
        cfg.EXP_PHASE = 'Training';
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

%% Initializing cleanup hooks
onCleanupTasks = cell(10,1); 

%% Warnings
warning('on','all'); %enabling warnings
beep off

%% Constructing and checking paths and getting next trial run id

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

%% Verifying connection to ripple system

% initialize xippmex, open connection to neural interface processor (NIP)
digout = 0;
if exist('xippmex','file')==3
    try
        switch cfg.protocol
            case 'tcp'
                try
                    digout = xippmex('tcp');
                    xippmex('addoper',129);
                    disp('Using TCP mode')
                catch
                    digout = xippmex();
                    disp('Using UDP mode')
                    warning('Inconsistent network protocol!')
                end
            case 'udp'
                try
                    digout = xippmex();
                    disp('Using UDP mode')

                catch
                    digout = xippmex('tcp');
                    xippmex('addoper',129);
                    disp('Using TCP mode')
                    warning('Inconsistent network protocol!')
                end
        end
        onCleanupTasks{9} = onCleanup(@() xippmex('close'));
    catch err
        warning('xippmex failed %s: %s\n', err.identifier, err.message);
    end
end
if digout
    fprintf('Ripple system found.\n')
    
    %ceck status of recording
    rippleRec = xippmex('trial');
    
    if isempty(strfind(rippleRec.filebase,cfg.SUBJECT))
        warning('Ripple''s file basename (%s) does NOT contain the subject''s id (%s)',rippleRec.filebase,cfg.SUBJECT);
    end
    if ~strcmp(rippleRec.status, 'recording') 
        warning('Ripple system connected but NOT recording. DRY RUN.');
    else
        fprintf('Ripple system recording to file %s%04d\n', rippleRec.filebase, rippleRec.incr_num);
    end
    
    onCleanupTasks{9} = onCleanup(@() xippmex('close'));  
else
    fprintf(2,['\n***************************************',...
             '\n** Ripple system NOT found! DRY RUN! **',...
             '\n***************************************\n']);
end
cfg.DIGOUT = digout;

%% Saving task function in log folder for documentation
task_function = [pwd filesep cfg.TASK_FUNCTION];
if ~isfile(task_function)
    clear onCleanupTasks
    error('%s.m should be in current working directory',cfg.TASK_FUNCTION);
end
copyfile(task_function,[cfg.PATH_LOG filesep cfg.BASE_NAME 'script.m']);

%% Launching the task
commandwindow
try
  cd('./scripts');
  task_smsl(cfg);
catch e
	fprintf('The identifier was:\n%s',e.identifier);
	fprintf('There was an error! The message was:\n%s',e.message);
end

%% Cleaning up
clear onCleanupTasks