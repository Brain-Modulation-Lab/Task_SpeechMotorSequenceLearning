function task_smsl(cfg)

%%% updated by Andrew Meier for SEQ-DBS project 2021/3/29
%%% Adapted for OR by Alan Bush 2021/04/01

% Speech Motor Sequence Learning taks for intraoperative experiments
% 
% The experiment is experimenter-paced or self-paced. 
%   ESCAPE: Ends experiment
%   any key: Advances to the next trial
%
% INPUT: cfg, configuration structure with the following fields:
%   cfg.SUBJECT             str, subject identifier
%   cfg.SESSION_LABEL       str, session label {'test','training','preop','intraop','emu'}
%   cfg.TASK                str, task name
%   cfg.TASK_VERSION        int, task version
%   cfg.RUN_ID              int, id of the run
%   cfg.PATH_TASK           str, path to task folder Stimuli folder
%   cfg.LOG_FILENAME        str, full filename (with path) to log file. 
%   cfg.EVENT_FILENAME      str, full filename (with path) to BIDS events file.  
%   cfg.TRIAL_FILENAME      str, full filename (with path) to table specifying the run's trials
%   cfg.SPEC_FILENAME       str, full filename (with path) for trial randomization table
%   cfg.KEYBOARD_ID         int, preferred keyboard by ID
%   cfg.AUDIO_ID_PLAYBACK            int, preferred audio device ID
%   cfg.AUDIO_AMP           float, audio amplitude. 
%   cfg.SCREEN_ID           int, preferred screen ID 
%   cfg.SKIP_SYNC_TEST      bool, should screen synchronization test be skipped? 
%   cfg.CONSERVE_VRAM_MODE	int, Psvchtoolbox ConserveVRAM Screen preference code
%   cfg.SCREEN_SYNC_COLOR   int(3), color of the corner square used for synchronization
%   cfg.SCREEN_SYNC_RECT    int(4), rectangle used for screen synchronization
%   cfg.DIGOUT              digital out parameter(s) to be passed to log_event function
%                             for Ripple intraop rig: bool indicating if Nomad is connected
%                             for Cash Lab rig it is a structure with fields
%                               cfg.DIGOUT.portObj - io64 object
%                               cfg.DIGOUT.portAddress - address of port
%   cfg.EXP_PHASE           str, {'Familiarization', 'Training', 'Test'} 
%   cfg.SYNC_BEEPS          bool, should synchronization beeps be played at
%                           the beggining of the task?
%
% COMMANDS:
%   spacebar: next trial
%   +: Increase stop-signal delay (SSD) by 50ms
%   -: Decrease stop-signal delay by (SSD) 50ms
%   s: Mark last stio trial as stopped before speech onset [SSD += 50ms]
%   i: Mark last stop trial as interrupted
%   c: Mark last stip trial as continued (failed stop) [SSD -= 50ms]
%   esc: End current run
%
% OUTPUT: Log file with all output to the console, Trial file containing
% description of each trial in the run and Event file containing precise
% timing of all events in the run. 

%% Set parameters

experiment_phase = cfg.EXP_PHASE;
subjName = cfg.SUBJECT;

%Options
ntrials_between_breaks = 48; % have subject take a break after this many trials

%Times      
go_trial_duration_ms = 1500; %%% time in milliseconds from onset of  GO cue to enabling keypress for next trial 
stoptrial_duration_ms = 2000; % time in milliseconds from onset of false GO cue to enabling keypress for next trial
spacerVisualAudio_ms = 1000; %time from orthographic representation to audio onset
visualStimDuration_ms = 1450; %duration of the orthographic representation 
interTrialGapDuration_ms = 1000; % enforced gap between key press and start of next trial
minJitter_ms = 500; %min time between end visual stim and start of go signal in ms
maxJitter_ms = 1000; %max time between end visual stim and start of go signal in ms
SSD_step_ms = 50; %step for modifying Stop Signal Delay on the fly in ms
SSD_adjustment_ms = 0; %adjustement over the presepcified SSD in the spec file in ms
keypress_duration_ms = 100; %duration of key press event

%Fonts
instructionFontSize = 70;
stimFontSize = 200;
fixcrossFontSize = 100;
stopFontSize = 100;
goFontSize = 100;

%color
fixcrossColor = [255,255,255];
goColor = [255,255,255];
stopColor = [255,255,255];

%text
fixcrossText = '+';
goText = '+';
stopText = '+';

% messages
first_instruction_message = ['On each trial, SILENTLY read and listen to the word. \n\n', ...
    'When you hear the beep, say the target word\nas QUICKLY and ACCURATELY as possible.'];
stoptrial_instruction_message = ['If you hear the buzzer, \n' ...
    'STOP saying the target word.']; 
break_message = 'Take a break!\nClick to continue.';
thanks_message = 'END OF TASK\nThank you!';

%Audio options
reallyneedlowlatency = 0; % flag for InitializePsychSound... set to 1 for lower latency

% Go cue % audio to play as START cue
start_cue_audio_file = [cfg.PATH_TASK filesep 'stim' filesep 'beep.wav']; 
GoBeepAmp = 0.15;

% Stop cue % audio to play on STOP trials
stoptrial_audio_file = [cfg.PATH_TASK filesep 'stim' filesep 'mixkit-game-show-buzz-in-3090.wav']; 
StopBeepAmp = 0.14;

% script initialization tones
InitBeepTone = 500;
InitBeepDuration = 0.05;
InitBeepAmp = 0.2 * cfg.SYNC_BEEPS;

%trigger codes
TRIG_FIXCROSS = 1;
TRIG_AUDITORY = 2;
TRIG_VISUAL = 4;
TRIG_GO = 8;
TRIG_STOP = 16;
TRIG_KEYPRESS = 32;
TRIG_ITG = 64;
TRIG_ESC = 128;

%% Initializaing psychtoolbox and celanup structures
onCleanupTasks = cell(20,1); %creating cleanup cell array container to enforce cleanup order
onCleanupTasks{20} = onCleanup(@() cd(cfg.PATH_TASK));
onCleanupTasks{1} = onCleanup(@() fprintf('\nRUN ID: %i\n',cfg.RUN_ID));

rng('shuffle');  

%% Initializing psychtoolbox
fprintf('Initializing psychtoolbox at %s for subject %s, %s task, session %s, run %i\n\n',datestr(now,'HH:MM:SS'),cfg.SUBJECT,cfg.TASK,cfg.SESSION_LABEL,cfg.RUN_ID);
PsychDefaultSetup(2);
 
% % Give Matlab priority to prevent timing issues
% priorityLevel=MaxPriority(ptb_window);
% Priority(priorityLevel);
    
% Initializing Keyboard
fprintf('Initializing Keyboard...'); 
if isempty(cfg.KEYBOARD_ID)
    fprintf('\nNo keyboard selected, using default. Choose KEYBOARD_ID from this table:\n'); 
    % Detect keyboards attached to system
    devices = struct2table(PsychHID('Devices'));  
    disp(devices);
end

%Set Stop/Start Keys
KbName('UnifyKeyNames')
keyCodeEscape = KbName('ESCAPE');
keyCodeInterrupted = KbName('i');
keyCodeContinued = KbName('c');
keyCodeStopped = KbName('s');
keyCodeIncrease = KbName('=+');
keyCodeDecrease = KbName('-_');
keyCodeStart = KbName('space');  %space to move to next trial

% Initialize Sound
fprintf('Initializing Sound...\n'); 
InitializePsychSound(reallyneedlowlatency); 

% getting audio playback device id
pa_devices = struct2table(PsychPortAudio('GetDevices'));
if isempty(cfg.AUDIO_ID_PLAYBACK) || ~ismember(cfg.AUDIO_ID_PLAYBACK,pa_devices.DeviceIndex)
    fprintf('\nNo audio device was selected, using default. Choose AUDIO_ID from this table:\n'); 
    disp(pa_devices);
else
    fprintf('The following audio playback device was selected');
    disp(pa_devices(pa_devices.DeviceIndex==cfg.AUDIO_ID_PLAYBACK,:));
end
% getting audio recording device id
if isempty(cfg.AUDIO_ID_RECORDING) || ~ismember(cfg.AUDIO_ID_RECORDING,pa_devices.DeviceIndex)
    fprintf('\nNo audio device was selected, using default. Choose AUDIO_ID from this table:\n'); 
    disp(pa_devices);
else
    fprintf('The following audio recording device (for voice detection only) was selected ');
    disp(pa_devices(pa_devices.DeviceIndex==cfg.AUDIO_ID_RECORDING,:));
end

% set playback device parameters
pa_reqlatencyclass = 1; % Try to get the lowest latency that is possible under the constraint of reliable playback.  
pa_freq = []; %loading default freq for devices
n_playback_channels = 2; %playing as stereo, converting to mono by hardware connector

% set STOP trial and recording device parameters
detection_safety_buffer_ms = 250; %%% wait this long in ms after GO beep start before starting voice detection (150ms+ recommended)
suggested_latency_seconds = 0.02; % 'suggestedLatency' to input to PsychPortAudio(‘Open’)
n_rec_chans = 2; % number of recording channels
allocated_record_seconds = 10; % 'amountToAllocateSecs' to input to PsychPortAudio(‘GetAudioData’)
detection_ops.waitscan_seconds = 0.005; % time to wait between recording scans
detection_ops.loudness_threshold = cfg.loudness_threshold;  % amplitude threshold for voice detection; range 0 to 1


% % % open playback and recording devices
playback_handle = PsychPortAudio('Open', cfg.AUDIO_ID_PLAYBACK, 1, pa_reqlatencyclass, pa_freq, n_playback_channels);
recording_handle = PsychPortAudio('Open', cfg.AUDIO_ID_RECORDING, 2, pa_reqlatencyclass, pa_freq, n_rec_chans, [], suggested_latency_seconds);
onCleanupTasks{19} = onCleanup(@() PsychPortAudio('Close')); % close playback and recording handles

% loading audio and verifying output frequency and resampling
pa_handle_status = PsychPortAudio('GetStatus', playback_handle);
pa_handle_Fs = pa_handle_status.SampleRate;

%construction initialization beeps
InitBeep = MakeBeep(InitBeepTone, InitBeepDuration, pa_handle_Fs) .* InitBeepAmp .* cfg.AUDIO_AMP;
InitBeep = [InitBeep;InitBeep];

%preload cue audio 
fprintf('Loading cue audio file...\n')
[go_beep, beep_Fs] = psychwavread(start_cue_audio_file);
% verifying output frequency and resampling
if pa_handle_Fs ~= beep_Fs
    fprintf('Resampling beep audio...\n')
    go_beep=resample(go_beep,pa_handle_Fs,beep_Fs);
    beep_Fs = pa_handle_Fs;
end
% converting to stereo row vectors 
go_beep = [go_beep(:,1)';go_beep(:,1)'] .* GoBeepAmp .* cfg.AUDIO_AMP;
go_beep_duration = size(go_beep,2) ./ beep_Fs;

%preload buzz audio 
fprintf('Loading buzz audio file...\n')
[stop_buzzer, stop_buzzer_Fs] = psychwavread(stoptrial_audio_file);
% verifying output frequency and resampling
if pa_handle_Fs ~= stop_buzzer_Fs
    fprintf('Resampling buzz audio...\n')
    stop_buzzer=resample(stop_buzzer,pa_handle_Fs,stop_buzzer_Fs);    
    stop_buzzer_Fs = pa_handle_Fs;
end
% converting to stereo row vectors 
stop_buzzer = [stop_buzzer(:,1)';stop_buzzer(:,1)'] .* StopBeepAmp .* cfg.AUDIO_AMP;
stop_buzzer_duration = size(go_beep,2) ./ stop_buzzer_Fs;

%% if doing voice onset detection, set up audio recording
if cfg.voiceTriggeredStopSignal
    detection_ops.repetitions = 0; % loop indefinitely until detection
    detection_ops.when = 0; % start immediately on function call
    PsychPortAudio('GetAudioData', recording_handle, allocated_record_seconds); % initialize recording device with buffer
end

%% Initialize Screen

fprintf('Initializing Screen...'); 
AssertOpenGL()
onCleanupTasks{18} = onCleanup(@() Priority(0));
Screen('Preference','Verbosity',3); %screen
%PsychImaging('PrepareConfiguration'); % Open window with default settings:
screens = Screen('Screens');
if isempty(cfg.SCREEN_ID)
    cfg.SCREEN_ID = max(screens);
end

if cfg.SKIP_SYNC_TEST
  fprintf('skipping sync test');
	Screen('Preference', 'VisualDebugLevel', 0);
  Screen('Preference', 'SkipSyncTests', 1);
	Screen('Preference', 'SuppressAllWarnings', 1);
end
if ~isempty(cfg.CONSERVE_VRAM_MODE)
    Screen('Preference','ConserveVRAM',cfg.CONSERVE_VRAM_MODE);
end

[ptb_window, ptb_window_rect] = Screen('OpenWindow', cfg.SCREEN_ID, BlackIndex(cfg.SCREEN_ID));
onCleanupTasks{17} = onCleanup(@() Screen('Close', ptb_window));
[screenXpixels, screenYpixels] = Screen('WindowSize', ptb_window);

white = WhiteIndex(ptb_window);
black = BlackIndex(ptb_window);

flipSyncState=0;

%% Initializing log files

%opening events file
eventFile = fopen(cfg.EVENT_FILENAME, 'a');  % Appending mode
onCleanupTasks{16} = onCleanup(@() fclose(eventFile));
fprintf(eventFile,'onset\tduration\tsample\ttrial_type\tstim_file\tvalue\tevent_code\n'); %BIDS event file in system time coord

%% create log file----------------------------------------------------------
% Implementing the log functionality: 
% The if-esle below will check what the last trial of the
% log file is. Save the index of this trial to a variable, and then at the
% start of the main loop switch 1:numTrial to var:num Trials.

trialFileName = cfg.TRIAL_FILENAME;
if ~isfile(trialFileName) % if first run, create a log file
    trialFile = fopen(trialFileName, 'at');
    onCleanupTasks{15} = onCleanup(@() fclose(trialFile));
    startTrial = 1;
    %randomizing trials 
    trials_spec = stimListRandomizer_DBS(cfg);
    writetable(trials_spec,cfg.SPEC_FILENAME,'Delimiter','\t','FileType','text');
else % if log present, ask user if they would like to continue from the last run, or start over
    prompt = ('\nThis run has already been started for this subject.  Do you want to continue where you left off? [Y/N]: ');
    resp = input(prompt,'s');
    if resp == 'Y' || resp == 'y'
        trialFile = fopen(trialFileName, 'r');
        trials_log = textscan(trialFile, '%d %d %.3f %.3f');
        fclose(trialFile);
        if isempty(trials_log{1})
          startTrial = 1;
        else
          startTrial = trials_log{1}(end);
        end
        fprintf("Starting from trial %i\n",startTrial);
        trialFile = fopen(trialFileName, 'at');
        onCleanupTasks{14} = onCleanup(@() fclose(trialFile));
    elseif resp == 'N' || resp == 'n'
        prompt = ('\nThis run has already been started for this subject. Would you like to start this run over? [Y/N]: ');
        % delete contents of log file? or keep them?
        resp = input(prompt,'s');
        if resp == 'Y' || resp == 'y'
            trialFile = fopen(trialFileName, 'at');
            onCleanupTasks{13} = onCleanup(@() fclose(trialFile));
            startTrial = 1;
            %randomizing trials 
            trials_spec = stimListRandomizer_DBS(cfg);
            writetable(trials_spec,cfg.SPEC_FILENAME,'Delimiter','\t','FileType','text');
        elseif resp == 'N' || resp == 'n'
            disp('Program ended.')
            return
        else
            disp('Invalid answer.')
            disp('Program ended.')
            return
        end
    else
        disp('Invalid answer.')
        disp('Program ended.')
        return
    end
end

%% loading trial specification file----------------------------------------------------------
trials_spec = readtable(cfg.SPEC_FILENAME,'Delimiter','\t','FileType','text');
first_stop_trial = find(trials_spec.is_stoptrial,1); % for displaying stoptrial instructions during familiarization
ntrials = height(trials_spec);
trials_spec.stim_conditions = num2str(trials_spec.stim_conditions);

%% Embedding de-indetified metadata into pairs of label and value triggers
log_metadata(cfg,eventFile);

%testing triggers
PsychPortAudio('FillBuffer', playback_handle, InitBeep);
pa_repetitions = 1; 
pa_when = 0;
pa_waitForStart = 1;
for i = 1:5
    BeepStartTime = PsychPortAudio('Start', playback_handle, pa_repetitions, pa_when, pa_waitForStart);
    log_event(eventFile, cfg.DIGOUT, BeepStartTime, 0.25, [], [], [], 255, 'Trigger test',1);
    WaitSecs('YieldSecs',0.25);
    log_event(eventFile, cfg.DIGOUT, [], 0.25, [], [], [], 0, 'Trigger test',0);
    WaitSecs('YieldSecs',0.25);
end

%% Initialization messages for experimenter

fprintf('Number of trials in run: %i \n',ntrials); % display the total number of trials
fprintf('SPACEBAR: next trial\n');
fprintf('+: Increase stop-signal delay (SSD) by 50ms\n');
fprintf('-: Decrease stop-signal delay by (SSD) 50ms\n');
fprintf('S: Mark last stio trial as stopped before speech onset [SSD += 50ms]\n');
fprintf('I: Mark last stop trial as interrupted\n');
fprintf('C: Mark last stip trial as continued (failed stop) [SSD -= 50ms]\n');
fprintf('ESCAPE: End current run\n');
WaitSecs(1.0);

%% experiment-------------------------------------------------------------

  Screen('TextSize', ptb_window, instructionFontSize);
  Screen('TextFont', ptb_window, char('Arial'));

  % Do dummy calls
  KbCheck;
  WaitSecs(0.1);
  GetSecs;

  %Set Instructions    
  DrawFormattedText(ptb_window, first_instruction_message, 'center', 'center', white, [], [], [], 1.5);
  flipSyncState = ~flipSyncState;
  Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
  [~, welcomeMesageTime] = Screen('Flip', ptb_window);
  log_event(eventFile, cfg.DIGOUT, welcomeMesageTime, [], [], [], [], 0, 'Melcome message', flipSyncState);  
  disp('Press Spacebar to proceed to experiment')  %Experimenter instructions

  %Waiting for keypress to start experiment
  [keyPressTime, keyCode] = KbWait(cfg.KEYBOARD_ID, 2);
  log_event(eventFile, cfg.DIGOUT, keyPressTime, [], [], [], [], TRIG_KEYPRESS, 'Key Press', flipSyncState);

  if any(ismember(find(keyCode),keyCodeEscape))
      log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_ESC, 'Escape', flipSyncState);
      fprintf("Escape key detected, ending run.\n");
      clear onCleanupTasks
      return
  end
 

  fprintf('Running Subject %s\n', subjName)
  
  % set up au

%% ----------------------------------------------------------------------------
% -------------------------- MAIN TRIAL LOOP ---------------------------------
% ----------------------------------------------------------------------------
startRunTime = GetSecs();
nextTrialRequested = 1; %only one space bar transitions from instructions to begging of experiment
 for itrial = startTrial:ntrials
      
    if (mod(itrial,ntrials_between_breaks) == 0) && (itrial ~= ntrials)  % Break after every X trials, but not on the last
        Screen('TextSize', ptb_window, instructionFontSize); %return to smaller text size (from larger fixation +)
        DrawFormattedText(ptb_window, break_message, 'center', 'center', white, [], [], [], 1.5);

        % Display break message
        flipSyncState = ~flipSyncState;
        Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
        [~, breakMesageTime] = Screen('Flip', ptb_window);
        log_event(eventFile, cfg.DIGOUT, breakMesageTime, [], [], [], [], 0, 'Break message', flipSyncState);  

        disp('Press Spacebar to continue experiment')  %Message to experimenter

        WaitSecs(3); %Forced pause to prevent inadvertently skipping the break
        
        [keyPressTime, keyCode] = KbWait(cfg.KEYBOARD_ID, 2);
        log_event(eventFile, cfg.DIGOUT, keyPressTime, [], [], [], [], TRIG_KEYPRESS, 'Key Press', flipSyncState);
        if any(ismember(find(keyCode),keyCodeEscape))
          log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_ESC, 'Escape', flipSyncState);
          fprintf("Escape key detected, ending run.\n");
          clear onCleanupTasks
          return
        end

    end

    %Fixation cross
    Screen('TextSize', ptb_window, fixcrossFontSize);
    DrawFormattedText(ptb_window, fixcrossText, 'center', 'center', fixcrossColor, [], [], [], 1.5); 
    flipSyncState = ~flipSyncState;
    Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
    [~, fixCrossTime] = Screen('Flip', ptb_window);
    code = TRIG_FIXCROSS;
    log_event(eventFile, cfg.DIGOUT, fixCrossTime, [], [], [], [], code, 'Fixation Cross', flipSyncState);  
      
    %preload stim information------------------------------------------------
    stim = char(trials_spec.word{itrial});  %Load word for this trial
    numString = num2str(trials_spec.stimnum(itrial)); %insert stimulus index here
    numString = pad(numString, 2, 'left', '0'); %inserts a 0 before numString for single digit numbers   
    audioStimFile = [numString,'_',lower(stim),'.wav'];
    audioStimPath = [cfg.PATH_TASK filesep 'stim' filesep audioStimFile]; %Load audio file
  
    %reading word audio file
    [audStim, stimFs]  = psychwavread(audioStimPath);
    if pa_handle_Fs ~= stimFs % verifying output frequency and resampling
        audStim=resample(audStim,pa_handle_Fs,stimFs);
        stimFs = pa_handle_Fs;
    end
    audStim = [audStim(:,1)';audStim(:,1)'] .* cfg.AUDIO_AMP; % converting to stereo row vectors 
    WordDuration = size(audStim,2)/stimFs;
    PsychPortAudio('FillBuffer', playback_handle, audStim);

    %Start trial on key press (any key)------------------------------
    if nextTrialRequested
      itgStartTime = GetSecs();
      nextTrialRequested = 0;
    else
      [itgStartTime, keyCode] = KbWait(cfg.KEYBOARD_ID, 2);
      log_event(eventFile, cfg.DIGOUT, itgStartTime, [], [], [], [], TRIG_KEYPRESS + TRIG_ITG, 'Key Press', flipSyncState);
      if any(ismember(find(keyCode),keyCodeEscape))
          log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_ESC, 'Escape', flipSyncState);
          fprintf("Escape key detected, ending run.\n");
          clear onCleanupTasks
          return
      end
    end
    
    % Manually control stopSignalDelay delay
    while any(ismember(find(keyCode),[keyCodeIncrease,keyCodeDecrease]))
        if any(ismember(find(keyCode), keyCodeIncrease))
          SSD_adjustment_ms = SSD_adjustment_ms + SSD_step_ms; %increasing SSD
          str = sprintf('SSD adj + %i ms = %i ms',SSD_step_ms,SSD_adjustment_ms); 
        elseif any(ismember(find(keyCode), keyCodeDecrease))
          SSD_adjustment_ms = SSD_adjustment_ms - SSD_step_ms; %decreasing SSD
          str = sprintf('SSD adj - %i ms = %i ms',SSD_step_ms,SSD_adjustment_ms); 
        else
          str = 'incorrect key';
        end
        fprintf('%s \n',str);
        log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_KEYPRESS, str, flipSyncState);
        WaitSecs(keypress_duration_ms/1000);
        log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], 0, "Key Press End", flipSyncState);
        [keyPressTime, keyCode] = KbWait(cfg.KEYBOARD_ID, 2);
    end
    
    % Mark stop last stop trial as Stopped, Interrupted or Continued  
    if any(ismember(find(keyCode),[keyCodeStopped,keyCodeInterrupted,keyCodeContinued]))
    	if any(ismember(find(keyCode), keyCodeStopped))
      	SSD_adjustment_ms = SSD_adjustment_ms + SSD_step_ms; %increasing SSD
        str = sprintf('Stopped: SSD adj + %i ms = %i ms',SSD_step_ms,SSD_adjustment_ms); 
      elseif any(ismember(find(keyCode), keyCodeInterrupted))
        str = sprintf('Interrupted: SSD adj = %i ms',SSD_adjustment_ms);
      elseif any(ismember(find(keyCode), keyCodeContinued))
      	SSD_adjustment_ms = SSD_adjustment_ms - SSD_step_ms; %decreasing SSD
        str = sprintf('Continued: SSD adj - %i ms = %i ms',SSD_step_ms,SSD_adjustment_ms); 
      else
        str = 'incorrect key';
      end
      fprintf('%s \n',str);
      log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_KEYPRESS, str, flipSyncState);
    end
      
    % print info about this trial
    if trials_spec.is_stoptrial(itrial)
        stop_latency_string = sprintf(' | STOP latency = %f ms', trials_spec.stop_latency_ms(itrial) + SSD_adjustment_ms);
    else
        stop_latency_string = '';
    end
    fprintf('Trial #%2i | stim = %s | STOP trial = %i %s \n', itrial, trials_spec.word{itrial}, trials_spec.is_stoptrial(itrial), stop_latency_string); 
    %disp(audioStimPath);        

    
    % if we're about to show the first STOP trial during the familiarization phase, give STOP trial instructions
    if  strcmp(experiment_phase,'Familiarization') && itrial == first_stop_trial
        Screen('TextSize', ptb_window, instructionFontSize); %return to smaller text size (from larger fixation +)
        DrawFormattedText(ptb_window, stoptrial_instruction_message, 'center', 'center', white, [], [], [], 1.5);

        flipSyncState = ~flipSyncState;
        Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
        [~, instructionMesageTime] = Screen('Flip', ptb_window);
        log_event(eventFile, cfg.DIGOUT, instructionMesageTime, [], [], [], [], 0, 'stop instructions', flipSyncState);  

        [keyPressTime, keyCode] = KbWait(cfg.KEYBOARD_ID, 2);
        log_event(eventFile, cfg.DIGOUT, keyPressTime, [], [], [], [], TRIG_KEYPRESS, 'Key Press', flipSyncState);
        if any(ismember(find(keyCode),keyCodeEscape))
          log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_ESC, 'Escape', flipSyncState);
          fprintf("Escape key detected, ending run.\n");
          clear onCleanupTasks
          return
        end
        
        %Fixation cross
        Screen('TextSize', ptb_window, fixcrossFontSize);        
        DrawFormattedText(ptb_window, fixcrossText, 'center', 'center', fixcrossColor .* white, [], [], [], 1.5); 
        flipSyncState = ~flipSyncState;
        Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
        [~, itgStartTime] = Screen('Flip', ptb_window);
        code = TRIG_FIXCROSS + TRIG_ITG;
        log_event(eventFile, cfg.DIGOUT, itgStartTime, [], [], [], [], code, 'Inter Trial Gap', flipSyncState);  
        
    end            

    %Display orthographic stim and play audio after ITG
    Screen('TextSize', ptb_window, stimFontSize); %return to stim text size (from larger fixation +)
    DrawFormattedText(ptb_window, stim, 'center', 'center', white, [], [], [], 1.5);
    flipSyncState = ~flipSyncState;
    Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
    [~, visualStimTime] = Screen('Flip', ptb_window, itgStartTime + interTrialGapDuration_ms/1000);
    code = TRIG_VISUAL;
    log_event(eventFile, cfg.DIGOUT, visualStimTime, visualStimDuration_ms/1000, [], trials_spec.stim_conditions(itrial), trials_spec.word{itrial}, code, 'Visual Stim Onset', flipSyncState);  

    pa_repetitions = 1; 
    pa_when = visualStimTime + spacerVisualAudio_ms/1000;
    pa_waitForStart = 1; %get time of audio start
    audioStimTime = PsychPortAudio('Start', playback_handle, pa_repetitions, pa_when, pa_waitForStart);
    code = TRIG_VISUAL + TRIG_AUDITORY;
    log_event(eventFile, cfg.DIGOUT, audioStimTime, WordDuration, [], trials_spec.stim_conditions(itrial), audioStimFile, code, 'Audio Stim Onset', flipSyncState);
    
    WaitSecs('UntilTime',audioStimTime + WordDuration);
    code = TRIG_VISUAL;
    log_event(eventFile, cfg.DIGOUT, [], [], [], trials_spec.stim_conditions(itrial), [], code, 'Audio Stim Offset', flipSyncState);
    
    %Return to fixation cross during jitter wait time
    Screen('TextSize', ptb_window, fixcrossFontSize);    
    DrawFormattedText(ptb_window, fixcrossText, 'center', 'center', fixcrossColor, [], [], [], 1.5); %
    flipSyncState = ~flipSyncState;
    Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
    [~, fixCrossTime] = Screen('Flip', ptb_window, visualStimTime + visualStimDuration_ms/1000);
    code = TRIG_FIXCROSS;
    log_event(eventFile, cfg.DIGOUT, fixCrossTime, [], [], trials_spec.stim_conditions(itrial), [], code, 'Fixation Cross', flipSyncState);  

    %loading start beep
    PsychPortAudio('FillBuffer', playback_handle, go_beep);

    %Set Jitter time for this trial
    waitTime = round((maxJitter_ms-minJitter_ms).*rand(1,1) + minJitter_ms); % set jittered waittime
    waitTime = waitTime / 1000; % convert ms to s

    % Generate the GO prompt (green + simultaneous with beep)
    pa_repetitions = 1; 
    pa_when = fixCrossTime + waitTime;
    pa_waitForStart = 1; %get time of audio start
    audioGoTime = PsychPortAudio('Start', playback_handle, pa_repetitions, pa_when, pa_waitForStart);
    code = TRIG_FIXCROSS + TRIG_GO;
    log_event(eventFile, cfg.DIGOUT, audioGoTime, go_beep_duration, [], trials_spec.stim_conditions(itrial), [], code, 'Go Beep', flipSyncState);

    %Return to fixation cross during jitter wait time
    Screen('TextSize', ptb_window, goFontSize);    
    DrawFormattedText(ptb_window, goText, 'center', 'center', white .* goColor, [], [], [], 1.5); %
    flipSyncState = ~flipSyncState;
    Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
    [~, fixCrossTime] = Screen('Flip', ptb_window);
    code = TRIG_GO;
    log_event(eventFile, cfg.DIGOUT, fixCrossTime, [], [], trials_spec.stim_conditions(itrial), [], code, 'Go Visual', flipSyncState);  
        
    trialEndTime = audioGoTime + go_trial_duration_ms/1000; %%% give subject this much time to respond (ms-->s)

    % show STOP cue if it's a STOP trial; on GO trial, wait for response
    if trials_spec.is_stoptrial(itrial) % if this is a stop trial
      
        %preparing STOP screen flip
        Screen('TextSize', ptb_window, stopFontSize);          
        DrawFormattedText(ptb_window, stopText, 'center', 'center', stopColor, [], [], [], 1.5); % prepare STOP visual stimulus
        flipSyncState = ~flipSyncState;
        Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);

        %loading stop buzz
        PsychPortAudio('FillBuffer', playback_handle, stop_buzzer);

        %playing buzz at indicated time
        pa_repetitions = 1; 
        pa_waitForStart = 1; %get time of audio start
        if ~cfg.voiceTriggeredStopSignal %%% if STOP is not to be triggered from voice onset, don't use voice detection
            pa_when = audioGoTime + (trials_spec.stop_latency_ms(itrial) + SSD_adjustment_ms)/1000;
        elseif cfg.voiceTriggeredStopSignal %%% if STOP is to be triggered from voice onset, use onlineVoiceDetection
            WaitSecs('UntilTime',audioGoTime + detection_safety_buffer_ms/1000); % wait so that we aren't triggering detection from the GO beep
            voice_detection_loop(recording_handle, detection_ops); % wait until voice detected, then continue
            pa_when = 0 + (trials_spec.stop_latency_ms(itrial) + SSD_adjustment_ms)/1000; % STOP initiation = [now] + extra latencies
        end
        audioStopTime = PsychPortAudio('Start', playback_handle, pa_repetitions, pa_when, pa_waitForStart); % play buzzer
        code = TRIG_FIXCROSS + TRIG_STOP;
        log_event(eventFile, cfg.DIGOUT, audioStopTime, stop_buzzer_duration, [], trials_spec.stim_conditions(itrial), [], code, 'Stop Buzzer', flipSyncState);

        [~, visualStopTime] = Screen('Flip', ptb_window);
        code = TRIG_STOP;
        log_event(eventFile, cfg.DIGOUT, visualStopTime, [], [], trials_spec.stim_conditions(itrial), [], code, 'Stop Visual', flipSyncState);  

        trialEndTime = audioGoTime + stoptrial_duration_ms/1000; %% wait until full stop trial duration has elapsed (ms-->s)
    end

    %prevent passing to next trial too soon while allowing to escape
    [keyPressTime, keyCode] = KbWait(cfg.KEYBOARD_ID, 2, trialEndTime);
    if any(ismember(find(keyCode),keyCodeEscape))
        log_event(eventFile, cfg.DIGOUT, [], [], [], [], [], TRIG_ESC, 'Escape', flipSyncState);
        fprintf("Escape key detected, ending run.\n");
        clear onCleanupTasks
        return
    end

    if keyPressTime < trialEndTime
      log_event(eventFile, cfg.DIGOUT, keyPressTime, [], [], [], [], TRIG_KEYPRESS, 'Key Press', flipSyncState);
      fprintf('Keypress noted, will continue after end of trial\n');
      WaitSecs('UntilTime',trialEndTime);
      nextTrialRequested = 1;
    end

    % message to experimenter
    elapsedTime = keyPressTime - startRunTime;
    fprintf('Trial #%2i of %i copleted at %02d:%02d \n', itrial, ntrials, floor(elapsedTime/60),round(mod(elapsedTime,60)));     
    
    % trial completed, update log file
    actualWaitTime = audioGoTime + go_beep_duration/2 - audioStimTime - WordDuration;
    logStr =  sprintf('%d %d %.3f %.3f \n', itrial, 1, actualWaitTime, 0);  %record trial completion + jitter time delay
    fprintf(trialFile,'%s',logStr);
end

%Calculate, display, and print total run duration in mins, close everything
release(deviceReader) %% release microphone
runTimeSecs = GetSecs() - startRunTime;
runTimeMins = runTimeSecs/60;
logStr =  sprintf('Total run duration: %.3f mins', runTimeMins);
fprintf(trialFile,'%s',logStr);

% Thank you message
Screen('TextSize', ptb_window, instructionFontSize);
DrawFormattedText(ptb_window, thanks_message, 'center', 'center', white, [], [], [], 1.5);
flipSyncState = ~flipSyncState;
Screen('FillRect', ptb_window, cfg.SCREEN_SYNC_COLOR .* flipSyncState, cfg.SCREEN_SYNC_RECT);
[~, thanksMesageTime] = Screen('Flip', ptb_window);
log_event(eventFile, cfg.DIGOUT, thanksMesageTime, [], [], [], [], 0, 'Thank you message', flipSyncState);

fprintf('\nTask %s, session %s, run %i for %s ended at %s\n',cfg.TASK,cfg.SESSION_LABEL,cfg.RUN_ID,cfg.SUBJECT,datestr(now,'HH:MM:SS'));
fprintf('\nRUN ID: %i\n',cfg.RUN_ID);

WaitSecs(2);

clear onCleanupTasks

