%% old version of the function that uses matlab's audioDeviceReader; updated versions use Psychtoolbox functions


%%% for testing the latency of onlineVoiceDetection.m
% by Andrew Meier

output_device_index = 5; 
reqlatencyclass = 1; 
pa_handle = PsychPortAudio('Open', [output_device_index], 1, reqlatencyclass, [], 2);

if ~exist('stop_buzzer','var')
    load stop_buzzer
end

% % % % playback_audio = stop_buzzer(:,:)'; 

% set options
detectionOps.recordLen = 10;            % length of recording
detectionOps.Fs = 48000;                 % sampling frequency
detectionOps.frameDur = 30;             % frame duration in ms
detectionOps.onDur = 10;                 % how long the intensity must exceed the threshold to be considered an onset (ms)
detectionOps.onThresh = 10;             % onset threshold
detectionOps.minVoiceOnsetTime = 0;
detectionOps.breakOnDetection = 1;
detectionOps.frameDurS = detectionOps.frameDur/1000; % convert ms to sec
frameLength = detectionOps.Fs*detectionOps.frameDurS;  % framelength in samples

pa_when = 0; % start playback immediately
pa_repetitions = 1; 
pa_waitForStart = 1; 

if exist('devicewriter','var')
    release(devicewriter)
end

deviceReader = audioDeviceReader(...
    'Device', 'Default', ...
    'SamplesPerFrame', frameLength, ...
    'SampleRate', detectionOps.Fs, ...
    'BitDepth', '16-bit integer');
setup(deviceReader)

PsychPortAudio('FillBuffer', pa_handle, stop_buzzer);

%% run voice detection
%%% run voice detection function until it detects voice
[~, ~, voiceOnsetDetected, recAudio] = onlineVoiceDetection_deviceReader(pa_handle,detectionOps);

audioStopTime = PsychPortAudio('Start', pa_handle, pa_repetitions, pa_when, pa_waitForStart);
% global tt; toc(tt)
release(deviceReader)
global gg; audioStopTime - gg

% % % % save recAudio recAudio
WaitSecs(2);
PsychPortAudio('Close', pa_handle);