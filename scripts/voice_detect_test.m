%%% wait for sounds onset, then play buzzer
% adapted from SimpleVoiceTriggerDemo.m
%%% by Andrew Meier

% set options
detection_ops.loudness_threshold = 0.1; % range 0 to 1
recording_device_index = 7; 
playback_device_index = 5; 
pa_reqlatencyclass = 1; % set to 1 to not force low latency
pa_freq = []; % use default frequency
reallyneedlowlatency = 0; %%% set to true to force psychportaudio to get very low latency

% recording parameters
detection_ops.waitscan_seconds = 0.005; % wait this long between recording scans
suggested_latency_seconds = 0.02; % 'suggestedLatency' to input to PsychPortAudio(‘Open’)
n_rec_chans = 2; % number of recording channels
allocated_record_seconds = 10; % 'amountToAllocateSecs' to input to PsychPortAudio(‘GetAudioData’)

% playback parameters
playback_when = 0; % start playback immediately
playback_repetitions = 1; 
playback_waitForStart = 1; 
n_playback_channels = 2; 


%% set up recording and playback
InitializePsychSound(reallyneedlowlatency)
PsychPortAudio('Close',[]); % close any devices that were left open
recording_handle = PsychPortAudio('Open', [recording_device_index], 2, pa_reqlatencyclass, pa_freq, n_rec_chans, [], suggested_latency_seconds);
playback_handle = PsychPortAudio('Open', [playback_device_index], 1, pa_reqlatencyclass, pa_freq, n_playback_channels);

PsychPortAudio('GetAudioData', recording_handle, allocated_record_seconds); % initialize recording device with buffer

% prepare buzzer
if ~exist('stop_buzzer','var')
    load stop_buzzer % assume stop_buzzer.mat stored in working directory or path
end
PsychPortAudio('FillBuffer', playback_handle, stop_buzzer);

% start recording
detection_ops.recording_repeititions = 0; % loop indefinitely until detection
detection_ops.recording_when = 0; % start immediately

% wait until voice detected, then continue
voice_detection_loop(recording_handle, detection_ops); 

%% buzzer playback, clean up
audioStopTime = PsychPortAudio('Start', playback_handle, playback_repetitions, playback_when, playback_waitForStart);

WaitSecs(2);
PsychPortAudio('Close', []);