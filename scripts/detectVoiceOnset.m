function [voiceOnsetDetected, voiceOnsetTime]  = detectVoiceOnset(samples, Fs, onDur, onThresh, minVoiceOnsetTime)
% function [voiceOnsetDetected, voiceOnsetTime]  = detectVoiceOnset(samples, Fs, onDur, onThresh, minVoiceOnsetTime)
% 
% Function to detect onset of speech production in an audio recording.
% Input samples can be from a whole recording or from individual frames.
%
% INPUTS        samples                 vector of recorded samples
%               Fs                      sampling frequency of samples
%               onDur                   how long the intensity must exceed the
%                                       threshold to be considered an onset (ms)
%               onThresh                onset threshold
%               minVoiceOnsetTime       time (s) before which voice onset
%                                       cannot be detected (due to
%                                       anticipation errors, throat
%                                       clearing etc) - often set to .09 at
%                                       beginning of recording/first frame
%
% OUTPUTS       voiceOnsetDetected      0 = not detected, 1 = detected
%               voiceOnsetTime          time (s) when voice onset occurred
%
% Adapted from ACE study in Jan 2021 by Elaine Kearney (elaine-kearney.com)
% Matlab 2019a 
%
%%

% set up parameters
winSize = round(Fs * .0015);                % analysis window = # samples per 1.5 ms
Incr = round(Fs * .001);                    % # samples to increment by (1 ms) (note: if you change this, onDur will no longer be in ms units)
time = 0:1/Fs:(length(samples)-1)/Fs;       % time vector
iter = 1;                                   % start iteration = 1
I = [];                                     % variable for storing dB SPL data
tm = [];                                    % variable for storing time data
BegWin = 1;                                 % first sample in analysis window
EndWin = BegWin + winSize;                  % last sample in analysis window
voiceOnsetDetected = 0;                     % voice onset (not yet detected)
voiceOnsetTime = [];                        % variable for storing voice onset time

% main loop
while (EndWin < length(samples)) && (voiceOnsetDetected == 0)
    
% % %     dat = detrend(samples(BegWin:EndWin, 1), 0);    % removes mean value from data in analysis window
    dat = samples(BegWin:EndWin);
    dat = dat - mean(dat); 
    %dat = convn(dat,[1;-.95]);             % legacy step: applies a high pass filter to the data
                                            % and may reduce sensitivity to production onset,
                                            % especially if stimulus starts with a voiceless consonant
    int = sum(dat.^2);                      % sum of squares
    I(iter) = 20*log10(int/.0015);          % calculate dB value per iteration
    tm(iter) = time(BegWin);                % store time info per iteration
    
    % criteria for voice onset:
    % (1) onDur has passed
    % (2) onThresh must have been continuously exceeded for the duration of onDur
    % (3) time of voice onset is greater than minVoiceOnsetTime
    
    if iter > onDur && voiceOnsetDetected == 0 && ...
            length(find(I(iter-onDur:iter) > onThresh)) == length(I(iter-onDur:iter)) && tm(iter-onDur) >= minVoiceOnsetTime
        voiceOnsetDetected = 1;             % onset detected
        voiceOnsetTime = tm(iter-onDur);    % time when onThresh was first reached
    end
    
    % increment analysis window and iteration by 1 (until voice onset detected)
    BegWin = BegWin + Incr;          
    EndWin = EndWin + Incr;                
    iter = iter + 1;                        
end

end