function SEQRun
%%% updated by Andrew Meier for SEQ-DBS project 2021/3/29

%change to countdown from 45 instead of counting up

%Script should be located in following directory on experimental computer:
%C:\speechres\SEQ-DBS\code\scripts

%% Set parameters

%Set Stop/Start Keys
stopkey = KbName('q');  %q to quit
startkey = KbName('space');  %space to move to next trial

%Set recording parameters
Fs = 44100;
bits = 16;
recObj = audiorecorder(Fs,bits,1);

% Set font sizes
InstructionFontSize = 70;
StimFontSize = 200;
FixationFontSize = 280;
go_trial_duration_ms = 1500; %%% time in milliseconds from onset of  GO cue to disappearance of GO cue
stoptrial_duration_ms = 2000; % time in milliseconds from onset of false GO cue to disappearance of STOP cue
show_stoptrial_visual_cue = 0; % if true, show a visual cue (e.g. red X) in addition to playing the buzzer for stop trials
    stoptrial_text = 'X';
    stoptrial_color = [1 0 0]; %%% RGB from 0 to 1; will get multiplied by WhiteIndex

%For jitter time:
minJitter = 500;
maxJitter = 1000;

show_countdown = 0; % if true, show in the top right corner how many trials remain 
ngroups = 5; % number of unique stimulus groups (subject groups)
ntrials_between_breaks = 45; % have subject take a break after this many trials
start_cue_audio_file = 'stim\beep.wav'; % audio to play as START cue
stoptrial_audio_file = 'stim\mixkit-game-show-buzz-in-3090.wav'; % audio to play on STOP trials

first_instruction_message = ['On each trial, SILENTLY read and listen to the word. \n \n', ...
    'When you hear the beep, say the target word\nas QUICKLY and ACCURATELY as possible.'];
stoptrial_instruction_message = ['If you hear the buzzer, \n' ...
    'STOP saying the target word.']; 
break_message = 'Take a break!\nClick to continue.';

%%
cd C:\speechres\SEQ-DBS\
addpath C:\speechres\SEQ-DBS\code\scripts
addpath C:\speechres\SEQ-DBS\code\stim   
addpath C:\speechres\SEQ-DBS\code\specFiles  

prompt = {['Subject ID'],['Group Number (1-5)',]...
    [sprintf('Experiment Phase?\n(0 = Familiarization, 1 = Training, 2 = Testing)')]};
dlgtitle = 'Experimenter Input';
dims = [1 50];
definput = {'DBSSEQ_Pilot1','1', '1'};
answer = inputdlg(prompt,dlgtitle,dims,definput);

subjName = answer{1};
groupNum = str2num(answer{2});
switch str2num(answer{3})
    case 0
        experiment_phase = 'Familiarization';
    case 1
        experiment_phase = 'Training';
    case 2
        experiment_phase = 'Test';
    otherwise
        error('Experiment Phase must be one of: 0 = Familiarization, 1 = Training, 2 = Testing') 
end

rng('shuffle');     % makes sure that rng seed isn't always the same

%check screen & OpenGL, other variable tests--------------------------------------------

clc; % Clear Matlab/Octave window
AssertOpenGL; % check for Opengl compatibility, abort otherwise
Screen('Preference', 'SkipSyncTests', 1);  %1 will force Psychtoolbox to continue 

% Check if all parameters input into GUI
if size(subjName,2)==0
    error('Must provide required input parameters');
elseif size(groupNum,2)==0
    error('Must provide required input parameters');
end

try
    foo = groupNum < 1;
catch
    error('group number must be integer');
end

%Test for groupNum in appropriate range
if (groupNum > ngroups) || (groupNum < 1) 
    error (['group number must be between 1 and ', num2str(ngroups)])
end



% Start timer for whole run
    runStart = tic;

%Create data directory for subject-----------------------------------------
if ~exist(strcat('sub-', subjName), 'dir')
  mkdir(strcat('sub-', subjName));
end

subjDir = strcat('sub-', subjName);

%% create log file----------------------------------------------------------
% Implementing the log functionality: 
% The if-esle below will check what the last trial of the
% log file is. Save the index of this trial to a variable, and then at the
% start of the main loop switch 1:numTrial to var:num Trials.

logFileName = strcat(subjName,'_', num2str(groupNum),'_',experiment_phase, '_log.txt');
logFileName = fullfile(subjDir, logFileName);
if ~exist(logFileName) % if first run, create a log file
    logFile = fopen(logFileName, 'at');
    curTrial = 1;
else % if log present, ask user if they would like to continue from the last run, or start over
    progress = 1;
    while progress
        prompt = ('This run has already been started for this subject.  Do you want to continue where you left off? [Y/N]: ');
        resp = input(prompt,'s');
        if resp == 'Y' || resp == 'y'
            progress = 0;
            logFile = fopen(logFileName, 'r');
            trials = textscan(logFile, '%d %d');
            curTrial = trials{1}(end);
            logFile = fopen(logFileName, 'at');
        elseif resp == 'N' || resp == 'n'
            prompt = ('This run has already been started for this subject. Would you like to start this run over? [Y/N]: ');
            % delete contents of log file? or keep them?
            resp = input(prompt,'s');
            if resp == 'Y' || resp == 'y'
            progress = 0;
            
            logFile = fopen(logFileName, 'at');
            curTrial = 1;
            elseif resp == 'N' || resp == 'n'
                disp('Program ended.')
                return
            else
                disp('Invalid answer.')
                disp('Program ended.')
            end

        else
            disp('Invalid answer.')
            disp('Program ended.')
            return
        end
    end
end

%% file handling----------------------------------------------------------

% import stim presentation order
%%% specfile columns specify: stim index, condition, is_stoptrial, stop trial latency
specFileName = strcat(answer{1},'_',answer{2},'_',experiment_phase);
specFile = strcat('specFiles\',specFileName,'.txt');
 [stimNums, stimConditions, stopTrials, stopLatencies] = textread(specFile,'%u %u %u %u'); 
%[stimNums] = textread(specFile,'%u %u');  %remove waits from specFile and use jitter in code instead
ntrials = size(stimNums,1); 
stimList = textread('stim\StimNumList.txt','%s'); %import code for num -> pseudoword translation
trials = table(cell(size(stimNums)), stimNums, logical(stopTrials), stopLatencies,...
    'VariableNames', {'word',       'stimnum', 'is_stoptrial',      'stop_latency_ms'}); 
for ii = 1:ntrials % get trials in the randomized order specified by stimNums
    trials.word{ii} = stimList{stimNums(ii)}; 
end
first_stop_trial = find(trials.is_stoptrial,1); % for displaying stoptrial instructions during familiarization

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
        fprintf(logFile,'%s',logStr);
        curTrial = curTrial + 1;

        DrawFormattedText(stimwindow, '+', 'center', 'center', WhiteIndex(stimwindow)); 
        Screen('Flip', stimwindow); %switch back to fixation cross

        %Check for early termination command    
        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
        elseif keyCode(stopkey)

            %update log file
            %movefile(logFileName,subjDir);
            logStr =  sprintf('%d %d \n', curTrial, 0);
            fprintf(logFile,'%s',logStr);
            fclose(logFile);
            
            fclose('all');
            Screen('CloseAll');
            return
            
        elseif ~keyCode(stopkey) || ~keyCode(startkey)
            disp('incorrect key')
            disp(curTrial)        
        end
        
    end
    
    %Calculate, display, and print total run duration in mins, close everything
    fclose(logFile);
    disp('Total run duration (mins):');
    runTimeSecs = toc(runStart);
    runTimeMins = runTimeSecs/60
    logStr =  sprintf('Total run duration: %.3f mins', runTimeMins);
    logFile = fopen(logFileName, 'at');
    fprintf(logFile,'%s',logStr);
    fclose(logFile);
    Screen('CloseAll');
    
catch ME   %if error occured during trial
    Screen('CloseAll');
    fclose('all');
    logStr =  sprintf('%d %d \n', curTrial, 0);
    logFile = fopen(logFileName, 'at');
    fprintf(logFile,'%s',logStr);
    fclose(logFile);
    rethrow(ME)

end