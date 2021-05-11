% function for holding in while loop until threshold is crossed in voice recording 
%
% adapted from SimpleVoiceTriggerDemo.m
%
% before calling this function, you will need to open the recording device under 'recording_handle' with PsychPortAudio('Open')
% ... and initialize the recording buffer with PsychPortAudio('GetAudioData')
%
% arg 1 = pa handle of the recording device
% arg 2 = ops struct, including fields:
%     loudness_threshold: range 0 to 1, default 0.1
%     waitscan_seconds: time to wait between recording scans, default to 0.005 (5ms)
%     repetitions: input to PsychPortAudio('Start'), default 0 to loop endlessly until detection
%     when: input to PsychPortAudio('Start'), default 0 to start immediately
%
% updated by Andrew Meier 2021/5/11

function voice_detection_loop(recording_handle, detection_ops)

if ~isfield(detection_ops,'loudness_threshold')
    detection_ops.loudness_threshold = 0.1; % default threshold
end
if ~isfield(detection_ops,'waitscan_seconds')
    detection_ops.waitscan_seconds = 0.005; % 5ms default
end
if ~isfield(detection_ops,'repetitions')
    detection_ops.repetitions = 0; % loop indefinitely until detection
end
if ~isfield(detection_ops,'when')
    detection_ops.when = 0; % start immediately on function call
end
PsychPortAudio('Start', recording_handle, detection_ops.repetitions, detection_ops.when);

%% detection loop
% Wait in a polling loop until some sound event of sufficient loudness is captured
level = 0;

% Repeat as long as below trigger-threshold:
while level < detection_ops.loudness_threshold
    % Fetch current audiodata:
    [audiodata]= PsychPortAudio('GetAudioData', recording_handle);

    % Compute maximum signal amplitude in this chunk of data:
    if ~isempty(audiodata)
        level = max(abs(sum(audiodata)));
    else
        level = 0;
    end

    % Below trigger-threshold?
    if level < detection_ops.loudness_threshold
        WaitSecs(detection_ops.waitscan_seconds); % Wait for waitscan_seconds before next scan:
    end
end
