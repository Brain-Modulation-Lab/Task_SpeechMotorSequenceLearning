function [percMissingSamples, voiceOnsetTime, voiceOnsetDetected, recAudio] = onlineVoiceDetection(deviceReader, ops, playback_audio)
%
% Development script to test online voice detection functionality as part
% of SAP study (not called as part of runExp; relevant lines were
% integrated into main script).
%
% Functionality:
%   records audio
%   checks for voice onset every frame - once detected, sends a pseudo
%       perturbation trigger (prints to screen)
%   plots the audio recording and voice onset (if detected) in real time
%
% OUTPUT:
%   percMissingSamples = percentage of missing samples across the audio
%   recording; ideally this should be close to zero but may increase
%   depending on processing power of computer and other processes running -
%   if percMissingSamples increases, you will need to increase the ops.frameDurS
%   variable to allow more time between frames

% INPUT; 
% deviceReader = object created by audioDeviceReader
% ops = struct containing the following fields (and their defaults):
% % % ops.recordLen            % length of recording in seconds
% % % ops.Fs                  % sampling frequency
% % % ops.frameDur         % frame duration in ms
% % % ops.onDur            % how long the intensity must exceed the threshold to be considered an onset (ms)
% % % ops.onThresh            % onset threshold
% % % ops.minVoiceOnsetTime = 0;    % minimum time before voice onset detection is allowed to occur
% % % ops.plotSound = 0;            % if true, generate plot of sound and voice dtection
% % % ops.consoleOutput = 0;        % if true, print results to command line
% % % ops.breakOnDetection = 1;     % if true, break the while loop as soon voice detection occurs

% Also calls detectVoiceOnset.m; note that there are 2 key variables passed
% to this function (ops.onThresh, ops.onDur) - these determine the threshold for
% detecting voicing and how long this threshold has to be met to be
% considered an onset. These values will vary per setup (e.g., mic, audio
% settings). Make sure you test for your setup.
%
% Developed in Matlab 2019a by Elaine Kearney (elaine-kearney.com)
%%% modified by Andrew Meier 2021/4/25 for use in seq-dbs experiment 
% April 2021
%

%% set variables
ops.onDurS = ops.onDur/1000;        % ops.onDur in seconds
ops.frameDurS = ops.frameDur/1000; % convert ms to sec
frameLength = ops.Fs*ops.frameDurS;  % framelength in samples

close all

% audio device reader settings
if ~exist('deviceReader','var') %%% if deviceReader object was not provided in function input, set it up
    closeDeviceWhenComplete = 1; 
    deviceReader = audioDeviceReader(...
        'Device', 'Default', ...   
        'SamplesPerFrame', frameLength, ...
        'SampleRate', ops.Fs, ...
        'BitDepth', '16-bit integer');
    setup(deviceReader)
else 
    closeDeviceWhenComplete = 0;
end

if ~exist('devicewriter', 'var')
    devicewriter = audioDeviceWriter(...
            'Device', 'Default', ...   
            'SampleRate', 48000, ...
            'BitDepth', '16-bit integer',...
            'SupportVariableSizeInput', true);
end

% if ops.breakOnDetection = true, end this function as soon as voice detection occurs
if ~isfield(ops,'breakOnDetection') 
    ops.breakOnDetection = false; 
end

% default is to allow voice onset to occur immediately
if ~isfield(ops,'minVoiceOnsetTime') 
    ops.minVoiceOnsetTime = 0; 
end

% initialize variable to store audio signal
nSamples = ops.recordLen*ops.Fs;
recAudio = nan(nSamples,1);
nMissingSamples = 0; % cumulative n missing samples between frames

% counter for # of frames
frameCount = 1;

% specify how far back in signal to look for voice onset (s)
onsetWindow = ops.onDurS+ops.frameDurS; 

% set up figure
if ~isfield(ops,'plotSound')
    ops.plotSound = true; 
end
if ~isfield(ops,'consoleOutput')
    ops.consoleOutput = true;
end
if ops.plotSound
    h=figure();
    xlabel('Time(s)');
    ylabel('Sound Pressure');
    g = animatedline(gca(h), 'MaximumNumPoints', nSamples);
    time = 0:1/ops.Fs:(nSamples-1)/ops.Fs;
    plotVoiceOnset = 0;
end

% start trial
voiceOnsetDetected = false;
voiceOnsetTime = NaN; % initialize

if ops.consoleOutput
    disp('Speak into microphone now.')
end

% start timer
curTrial=tic;

%% read audio data
while toc(curTrial) < ops.recordLen
%     global tt; tt = tic;
    global gg; gg = GetSecs;
    % find beginning/end indices of frame, accounting for previous missing samples
    begIdx = (frameCount*frameLength) - (frameLength-1) + nMissingSamples;
    endIdx = (frameCount*frameLength) + nMissingSamples;
    
    % read audio data
%     [audioFromDevice, numOverrun] = deviceReader();     % read one frame of audio data
    [audioFromDevice, numOverrun] = step(deviceReader);     % read one frame of audio data
    numOverrun = double(numOverrun);    % convert from uint32 to type double
    if numOverrun > 0, recAudio(begIdx:begIdx+numOverrun-1) = 0; end      % set missing samples to 0
    recAudio(begIdx+numOverrun:endIdx+numOverrun) = audioFromDevice;    % save frame to audio vector
    nMissingSamples = nMissingSamples + numOverrun;     % keep count of cumulative missng samples between frames
    
    % plot audio data
    if ops.plotSound
        addpoints(g, time, recAudio(1:nSamples))
        drawnow()
    end
        
    % check for voice onset once 1.5 times ops.onDur has passed
    if ~voiceOnsetDetected && frameCount > onsetWindow/ops.frameDurS
        
            % look for voice onset in previous samples covering 1.5 times ops.onDur
            [voiceOnsetDetected, voiceOnsetTime]  = detectVoiceOnset(...
                recAudio(endIdx+numOverrun-(round(onsetWindow*ops.Fs)):endIdx+numOverrun,:), ...
                ops.Fs, ops.onDur, ops.onThresh, ops.minVoiceOnsetTime);
            
            % update voice onset time based on index of data passed to voice onset function
            voiceOnsetTime = voiceOnsetTime + (endIdx+numOverrun-(round(onsetWindow*ops.Fs)))/ops.Fs;

        % once voice onset is detected, "send" the pert trigger
    elseif voiceOnsetDetected == 1
%         step(devicewriter, playback_audio)
        
        if ops.consoleOutput
            disp('Perturbation Trigger');
        end    
        if ops.plotSound
            if plotVoiceOnset == 0

                % add voice onset to plot
                xline(voiceOnsetTime, 'Color', 'r', 'LineWidth', 3);
                drawnow update
                plotVoiceOnset = 1;

            end
        end
        
        if ops.breakOnDetection
            break
        end
    end
    
    % update frame counter
    frameCount = frameCount+1;
end

% release device
if closeDeviceWhenComplete
    release(deviceReader)
end


    
percMissingSamples = (nMissingSamples/(ops.recordLen*ops.Fs))*100; 
end
