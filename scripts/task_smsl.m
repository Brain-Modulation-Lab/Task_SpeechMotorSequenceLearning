function task_smsl(cfg)

%%% updated by Andrew Meier for SEQ-DBS project 2021/3/29
%%% Adapted for OR by Alan Bush 2021/04/01

% Speech Motor Sequence Learning taks for intraoperative experiments

%% Set parameters

groupNum = cfg.GROUP_NUM;
experiment_phase = cfg.EXP_PHASE;
subjName = cfg.SUBJECT;
subjDir = cfg.PATH_LOG;

InstructionFontSize = 70;
StimFontSize = 200;
go_trial_duration_ms = 1500; %%% time in milliseconds from onset of  GO cue to disappearance of GO cue
stoptrial_duration_ms = 2000; % time in milliseconds from onset of false GO cue to disappearance of STOP cue
show_stoptrial_visual_cue = 0; % if true, show a visual cue (e.g. red X) in addition to playing the buzzer for stop trials
%FixationFontSize = 280;
%stoptrial_text = 'X';
%stoptrial_color = [1 0 0]; %%% RGB from 0 to 1; will get multiplied by WhiteIndex

%For jitter time:
minJitter = 500;
maxJitter = 1000;

show_countdown = 0; % if true, show in the top right corner how many trials remain 
ntrials_between_breaks = 45; % have subject take a break after this many trials
start_cue_audio_file = 'stim\beep.wav'; % audio to play as START cue
stoptrial_audio_file = 'stim\mixkit-game-show-buzz-in-3090.wav'; % audio to play on STOP trials

% messages
first_instruction_message = ['On each trial, SILENTLY read and listen to the word. \n \n', ...
    'When you hear the beep, say the target word\nas QUICKLY and ACCURATELY as possible.'];
stoptrial_instruction_message = ['If you hear the buzzer, \n' ...
    'STOP saying the target word.']; 
break_message = 'Take a break!\nClick to continue.';

% script initialization tones
AudioBeepTone = 500;
AudioBeepDuration = 0.2;

%% Initializaing psychtoolbox and celanup structures
onCleanupTasks = cell(20,1); %creating cleanup cell array container to enforce cleanup order

%% Initializing log files

%opening events file
eventFile = fopen(cfg.EVENT_FILENAME, 'a');  % Appending mode
onCleanupTasks{19} = onCleanup(@() fclose(eventFile));
fprintf(eventFile,'onset\tduration\tsample\ttrial_type\tstim_file\tvalue\tevent_code\n'); %BIDS event file in system time coord

%% create log file----------------------------------------------------------
% Implementing the log functionality: 
% The if-esle below will check what the last trial of the
% log file is. Save the index of this trial to a variable, and then at the
% start of the main loop switch 1:numTrial to var:num Trials.

% trialFileName = strcat(subjName,'_', num2str(groupNum),'_',experiment_phase, '_log.txt');
% trialFileName = fullfile(subjDir, trialFileName);

trialFileName = cfg.TRIAL_FILENAME;
if ~isfile(trialFileName) % if first run, create a log file
    trialFile = fopen(trialFileName, 'at');
    onCleanupTasks{18} = onCleanup(@() fclose(trialFile));
    curTrial = 1;
    %randomizing trials
    trial_list_all_blocks = stimListRandomizer_DBS(cfg);
    writetable(table(trial_list_all_blocks),cfg.SPEC_FILENAME,'Delimiter','\t','FileType','text');
else % if log present, ask user if they would like to continue from the last run, or start over
    progress = 1;
    while progress
        prompt = ('This run has already been started for this subject.  Do you want to continue where you left off? [Y/N]: ');
        resp = input(prompt,'s');
        if resp == 'Y' || resp == 'y'
            progress = 0;
            trialFile = fopen(trialFileName, 'r');
            trials = textscan(trialFile, '%d %d');
            curTrial = trials{1}(end);
            trialFile = fopen(trialFileName, 'at');
            onCleanupTasks{17} = onCleanup(@() fclose(trialFile));
        elseif resp == 'N' || resp == 'n'
            prompt = ('This run has already been started for this subject. Would you like to start this run over? [Y/N]: ');
            % delete contents of log file? or keep them?
            resp = input(prompt,'s');
            if resp == 'Y' || resp == 'y'
              progress = 0;
              trialFile = fopen(trialFileName, 'at');
              onCleanupTasks{16} = onCleanup(@() fclose(trialFile));
              curTrial = 1;
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
end


%% file handling----------------------------------------------------------

%writetable(dbTrials,[filepath filesep name '-rand' ext],'Delimiter','\t','FileType','text')

% import stim presentation order
%%% specfile columns specify: stim index, condition, is_stoptrial, stop trial latency
% specFileName = strcat(answer{1},'_',answer{2},'_',experiment_phase);
% specFile = strcat('specFiles\',specFileName,'.txt');

trial_list = readtable(cfg.SPEC_FILENAME,'Delimiter','\t','FileType','text');
stimNums = trial_list.stimNums;
stimConditions = trial_list.stimConditions;
stopTrials = trial_list.stopTrials;
stopLatencies = trial_list.stopLatencies;

% specFile = cfg.SPEC_FILENAME;
% [stimNums, stimConditions, stopTrials, stopLatencies] = textscan(specFile,'%u %u %u %u'); 


%[stimNums] = textread(specFile,'%u %u');  %remove waits from specFile and use jitter in code instead
ntrials = size(stimNums,1); 
stimList = textread('stim\StimNumList.txt','%s'); %import code for num -> pseudoword translation
trials = table(cell(size(stimNums)), stimNums, logical(stopTrials), stopLatencies,...
    'VariableNames', {'word',       'stimnum', 'is_stoptrial',      'stop_latency_ms'}); 
for ii = 1:ntrials % get trials in the randomized order specified by stimNums
    trials.word{ii} = stimList{stimNums(ii)}; 
end
first_stop_trial = find(trials.is_stoptrial,1); % for displaying stoptrial instructions during familiarization


%% Initializing psychtoolbox
fprintf('Initializing psychtoolbox at %s for subject %s, %s task, session %s, run %i\n\n',datestr(now,'HH:MM:SS'),cfg.SUBJECT,cfg.TASK,cfg.SESSION_LABEL,cfg.RUN_ID);
PsychDefaultSetup(2);

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
stopkey = KbName('ESCAPE');
startkey = KbName('space');  %space to move to next trial

% Initialize Sound
fprintf('Initializing Sound...\n'); 
InitializePsychSound; 

% getting audio device id
pa_devices = struct2table(PsychPortAudio('GetDevices'));
if isempty(cfg.AUDIO_ID) || ~ismember(cfg.AUDIO_ID,pa_devices.DeviceIndex)
    fprintf('\nNo audio device was selected, using default. Choose AUDIO_ID from this table:\n'); 
    disp(pa_devices);
else
    fprintf('The following audio device was selected');
    disp(pa_devices(pa_devices.DeviceIndex==cfg.AUDIO_ID,:));
end
pa_mode = 1; %1 == sound playback only; 
pa_reqlatencyclass = 1; % Try to get the lowest latency that is possible under the constraint of reliable playback.  
pa_freq = []; %loading default freq for device
pa_channels = 2; %playing as stereo, converting to mono by hardware connector
pa_handle = PsychPortAudio('Open', cfg.AUDIO_ID, pa_mode, pa_reqlatencyclass, pa_freq, pa_channels);
onCleanupTasks{18} = onCleanup(@() PsychPortAudio('Close', pa_handle));

% loading audio and verifying output frequency and resampling
pa_handle_status = PsychPortAudio('GetStatus', pa_handle);
pa_handle_Fs = pa_handle_status.SampleRate;

%construction initialization beeps
AudioBeep = MakeBeep(AudioBeepTone, AudioBeepDuration, pa_handle_Fs)*cfg.AUDIO_AMP;
AudioBeep = [AudioBeep;AudioBeep];

% Initialize Screen
fprintf('Initializing Screen...'); 
AssertOpenGL()
onCleanupTasks{16} = onCleanup(@() Priority(0));
Screen('Preference','Verbosity',3); %screen
PsychImaging('PrepareConfiguration'); % Open window with default settings:
screens = Screen('Screens');
if isempty(cfg.SCREEN_ID)
    cfg.SCREEN_ID = max(screens);
end
white = WhiteIndex(cfg.SCREEN_ID);
black = BlackIndex(cfg.SCREEN_ID);
if cfg.SKIP_SYNC_TEST
  fprintf('skipping sync test');
	Screen('Preference', 'VisualDebugLevel', 0);
  Screen('Preference', 'SkipSyncTests', 1);
	Screen('Preference', 'SuppressAllWarnings', 1);
end
if ~isempty(cfg.CONSERVE_VRAM_MODE)
    Screen('Preference','ConserveVRAM',cfg.CONSERVE_VRAM_MODE);
end

[ptb_window, ptb_window_rect] = Screen('OpenWindow', cfg.SCREEN_ID, black);
onCleanupTasks{15} = onCleanup(@() Screen('Close', ptb_window));
[screenXpixels, screenYpixels] = Screen('WindowSize', ptb_window);


%% Embedding de-indetified metadata into pairs of label and value triggers
log_metadata(cfg,eventFile);

%testing triggers
PsychPortAudio('FillBuffer', pa_handle, AudioBeep);
pa_repetitions = 1; 
pa_when = 0;
pa_waitForStart = 1;
for i = 1:5
    BeepStartTime = PsychPortAudio('Start', pa_handle, pa_repetitions, pa_when, pa_waitForStart);
    log_event(eventFile, cfg.DIGOUT, BeepStartTime, 0.25, [], [], [], 255, 'Trigger test',1);
    WaitSecs('YieldSecs',0.25);
    log_event(eventFile, cfg.DIGOUT, [], 0.25, [], [], [], 0, 'Trigger test',0);
    WaitSecs('YieldSecs',0.25);
end

%%
% cd C:\speechres\SEQ-DBS\
% addpath C:\speechres\SEQ-DBS\code\scripts
% addpath C:\speechres\SEQ-DBS\code\stim   
% addpath C:\speechres\SEQ-DBS\code\specFiles  

rng('shuffle');     % makes sure that rng seed isn't always the same

%check screen & OpenGL, other variable tests--------------------------------------------

%Create data directory for subject-----------------------------------------



disp('Number of trials in run: '); % display the total number of trials
disp(ntrials);
disp('Press and hold "Q" to exit program early.');
WaitSecs(1.0);

%% experiment-------------------------------------------------------------

try  %for error handling
    screens=Screen('Screens');
    screenNumber=max(screens);
    
%     HideCursor;
    %gray=GrayIndex(screenNumber);  %For gray screen
    black=BlackIndex(screenNumber);
    [stimwindow, wRect]=Screen('OpenWindow',screenNumber, black); %gray);
    Screen('TextSize', stimwindow, InstructionFontSize);
    Screen('TextFont', stimwindow, char('Arial'));
    
    % Do dummy calls
    KbCheck;
    WaitSecs(0.1);
    GetSecs;

     % Give Matlab priority to prevent timing issues
    priorityLevel=MaxPriority(stimwindow);
    Priority(priorityLevel);
    
    %Set Instructions    
    DrawFormattedText(stimwindow, first_instruction_message, 'center', 'center', WhiteIndex(stimwindow));
    Screen('Flip', stimwindow);
    disp('Press Spacebar to proceed to experiment')  %Experimenter instructions
    [~, keyCode] = KbWait([], 2);
                
    Screen('Flip', stimwindow); %clear to grey
    WaitSecs(1.000);
    
    %preload cue audio 
    [beep, beepFs] = audioread(start_cue_audio_file); 
    [stop_buzzer, stop_buzzer_Fs] = audioread(stoptrial_audio_file); 
    
    fprintf('Running Subject %s\n', subjName)

%% ----------------------------------------------------------------------------
% -------------------------- MAIN TRIAL LOOP ---------------------------------
% ----------------------------------------------------------------------------
    for itrial = curTrial:ntrials
            
        trialCountdown = num2str(ntrials-itrial); %calculate number of trials left in run
        
        if (mod(itrial,ntrials_between_breaks) == 0) && (itrial ~= ntrials)  % Break after every X trials, but not on the last
            Screen('TextSize', stimwindow, InstructionFontSize); %return to smaller text size (from larger fixation +)
            DrawFormattedText(stimwindow, break_message, 'center', 'center', WhiteIndex(stimwindow));
            Screen('Flip', stimwindow); % Display break message
            disp('Press Spacebar to continue experiment')  %Message to experimenter
            [~, keyCode] = KbWait([], 2);
            Screen('Flip', stimwindow); %clear to blank screen
            WaitSecs(1.000);
        end
        
        %preload stim information------------------------------------------------
        stim = char(trials.word{itrial});  %Load word for this trial
        trialNumString = num2str(itrial);
        numString = num2str(trials.stimnum(itrial)); %insert stimulus index here
        numString = pad(numString, 2, 'left', '0'); %inserts a 0 before numString for single digit numbers   
        recordFile = fullfile(subjDir, [subjName '_' num2str(groupNum) '_' experiment_phase '_' trialNumString '_' stim '.wav']);

        % print info about this trial
        audStimFile = strcat('C:\speechres\SEQ-DBS\code\stim\',numString,'_',lower(stim),'.wav'); %Load audio file
        if trials.is_stoptrial(itrial)
            stop_latency_string = [' .............. STOP latency = ', num2str(trials.stop_latency_ms(itrial)), 'ms'];
        elseif ~trials.is_stoptrial(itrial)
            stop_latency_string = '';
        end
        disp(['Trial # ', num2str(curTrial), ' ........ ', 'stim = ''', char(trials.word{itrial}), ''' ..............',...
            ' STOP trial = ', num2str(trials.is_stoptrial(itrial)), stop_latency_string]); 
        disp(audStimFile);        
        
        [audStim, stimFs] = audioread(audStimFile);
        message2 = stim;
        WordDuration = length(audStim)/stimFs;
        
        %Start trial on key press (space bar)------------------------------
         [~, keyCode] = KbWait([], 2);
        if keyCode(startkey) 
        
        % if we're about to show the first STOP trial during the familiarization phase, give STOP trial instructions
        if  strcmp(experiment_phase,'Familiarization') && itrial == first_stop_trial
            Screen('TextSize', stimwindow, InstructionFontSize); %return to smaller text size (from larger fixation +)
            DrawFormattedText(stimwindow, stoptrial_instruction_message, 'center', 'center', WhiteIndex(stimwindow));
            Screen('Flip', stimwindow); 
            [~, keyCode] = KbWait([], 2); %%% wait for another Spacebar press
        end            
            
        
            
        %Display orthographic stim and play audio
        Screen('TextSize', stimwindow, StimFontSize); %return to stim text size (from larger fixation +)
        DrawFormattedText(stimwindow, message2, 'center', 'center', WhiteIndex(stimwindow));
        if show_countdown
            DrawFormattedText(stimwindow, trialCountdown, 'left', WhiteIndex(stimwindow));
        end
        Screen('Flip', stimwindow);  % flip screen to display text
        WaitSecs(1.000);   %added during piloting to make sure audio & visual synced via Zoom
        soundsc(audStim, stimFs); %.48 sec long
        WaitSecs(WordDuration); % = 0.47 s, waits until end of sound
        actualWaitTic = tic; % actualWaitTime timer starts, to calculate actual delay between stimulus and beep
        WaitSecs(0.945); %total present time = 1.45 secs 
        
        %Return to fixation cross during jitter wait time
        DrawFormattedText(stimwindow, '+', 'center', 'center', WhiteIndex(stimwindow)); %
        Screen('Flip', stimwindow);

        %Set Jitter time for this trial
        waitTime = round((maxJitter-minJitter).*rand(1,1) + minJitter); % set jittered waittime
        waitTime = waitTime / 1000; % convert ms to s
        WaitSecs(waitTime); % 0.5 - 1 sec (jittered)
        
        % Generate the GO prompt (green + simultaneous with beep)
        %%%%% NB: commented visual stimulus for GO cue (green cross) because synchronizing audio+visuals over Zoom is unreliable
        stop_latency_tic = tic; %%% right before GO cue, start timer for STOP cue onset 
        soundsc(beep, beepFs);
        if ~trials.is_stoptrial(itrial) % if GO trial
            time_flip = length(beep)/beepFs;
            WaitSecs(time_flip/2)
            %Screen('TextSize', w, FixationFontSize);  %increase text size of +
            %DrawFormattedText(w, '+', 'center', 'center', [0 255 0]);  %change color of +, simultaneous with beep
            %Screen('Flip', w); %Flip screen to green fixation cross
        end
        actualWaitTime = toc(actualWaitTic); 
        waitTimeDiff = actualWaitTime - (waitTime+0.945);

        if waitTimeDiff > 0.05  %need to add 1.45 present time to jitter time
            disp('Warning: jitter timing off by more than 50 ms'); % may not apply to STOP trials
        end

        % Record response
        record(recObj, 2);
        
        % show STOP cue if it's a STOP trial; on GO trial, wait for response
        if trials.is_stoptrial(itrial) % if this is a stop trial
            if show_stoptrial_visual_cue
                DrawFormattedText(stimwindow, stoptrial_text, 'center', 'center', WhiteIndex(stimwindow) * stoptrial_color); % prepare STOP visual stimulus
            end
            while toc(stop_latency_tic) < trials.stop_latency_ms(itrial)/1000; end %% wait until STOP latency has elapsed (ms-->s)
            soundsc(stop_buzzer, stop_buzzer_Fs); % play STOP audio stimulus
            if show_stoptrial_visual_cue
                Screen('Flip', stimwindow); % show STOP visual stimulus
            end
            remaining_time_ms = stoptrial_duration_ms - trials.stop_latency_ms(itrial); 
            WaitSecs(remaining_time_ms/1000); %% wait until full stop trial duration has elapsed (ms-->s)
        elseif ~trials.is_stoptrial(itrial) % if GO trial
            WaitSecs(go_trial_duration_ms/1000); %%% give subject this much time to respond (ms-->s)
        end
        
        fooAudio = getaudiodata(recObj);
        audiowrite(recordFile,fooAudio,Fs,'BitsPerSample',bits);
        clear fooAudio;

        % trial completed, update log file
        %logStr =  sprintf('%d %d \n', curTrial, 1);
        logStr =  sprintf('%d %d %.3f %.3f \n', itrial, 1, actualWaitTime, waitTimeDiff);  %record trial completion + jitter time delay
        fprintf(trialFile,'%s',logStr);
        curTrial = curTrial + 1;

        DrawFormattedText(stimwindow, '+', 'center', 'center', WhiteIndex(stimwindow)); 
        Screen('Flip', stimwindow); %switch back to fixation cross

        %Check for early termination command    
        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
        elseif keyCode(stopkey)

            %update log file
            %movefile(logFileName,subjDir);
            logStr =  sprintf('%d %d \n', curTrial, 0);
            fprintf(trialFile,'%s',logStr);
            fclose(trialFile);
            
            fclose('all');
            Screen('CloseAll');
            return
            
        elseif ~keyCode(stopkey) || ~keyCode(startkey)
            disp('incorrect key')
            disp(curTrial)        
        end
        
    end
    
    %Calculate, display, and print total run duration in mins, close everything
    fclose(trialFile);
    disp('Total run duration (mins):');
    runTimeSecs = toc(runStart);
    runTimeMins = runTimeSecs/60
    logStr =  sprintf('Total run duration: %.3f mins', runTimeMins);
    trialFile = fopen(trialFileName, 'at');
    fprintf(trialFile,'%s',logStr);
    fclose(trialFile);
    Screen('CloseAll');
    
catch ME   %if error occured during trial
    Screen('CloseAll');
    fclose('all');
    logStr =  sprintf('%d %d \n', curTrial, 0);
    trialFile = fopen(trialFileName, 'at');
    fprintf(trialFile,'%s',logStr);
    fclose(trialFile);
    rethrow(ME)

end