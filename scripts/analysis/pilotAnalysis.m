function pilotAnalysis(subjName, groupNum, Training, initials, varargin) 
%To do- make sure trials that are 'Quit' mark that they still need to be
%scored (and check if trial scored prior to moving to next on resume)
%Compare with sample trials structure from MM (SEQMP)- make sure it works
%with group average code
%Add jiter time to data structure
%Separate coding for onset/offset errors?
%Add coding for type of error in scoring GUI (or do later in Praat?)- see
%Liz's pert analysis code to merge these
%Add counts code per stimulus item? (compare to manuscript)

%sample input pilotAnalysis('SEQ_Pilot2', 2, 0, 'HM') 
%Training: enter 1 for training, test = 0
%pass 'redo' for varargin to review or redo a specific trial after a first pass run, in case a mistake is made during that trial during the first pass.
%Usage example:
%pilotAnalysis('SEQ_Pilot2', 2, 0, 'HM', 'redo', 17) %This redoes only trial #17.

%This function uses spec file and audio recording files from a subject to generate mat structure 
%with utterance duration and accuracy (with duration measured only for accurate trials)
%Part 2 of code completes subject-level summary statistics
%addpath 'C:\speechres\SEQ-FTD\code\scripts\analysis' prior to running

%...cond: 1 = trained, 2 = novel

% ACCURACY
%     case 1 = accurate
%     case 0 = error

%CONFIDENCE
%     case 1 = confident
%     case 0 = low confidence, should review file

%STATUS
%       case 1 = scoring complete
%       case 0 = incomplete (e.g. quit program prior to trial completion)

% mat files, 1 x nTrials struct with
%       stim - e.g. 'PLIRTH'
%       stimFileName (.wav file recording name)
%       stimNum
%       duration (in s)
%       rt (in s)
%       trial #
%       accuracy
%       confidence in accuracy rating (check box; 1 or 0)
%       condition ('trained' or 'novel')
%       status ('scored' or 'incomplete')

baseDir = 'C:/speechres/SEQ-FTD/';
subjDir = strcat('sub-', subjName);

%set of variables to be passed between nested functions
global buttonVals
global done
global button_quit
global accuracyLowConfid

if nargin < 2
    error('Must provide required input parameters');
end

if groupNum > 4 
    error('Invalid group number'); 
end

%Set onset/offset threshold & duration
OnDur = 20;    %this value is in ms and controls how long the intensity should exceed the threshold to be considered an onset
onThresh = -20;   % onset threshold %originally set to 10 for MP pilot code, -20 for Practice code
OffDur = 80;  %originally set to 75
offThresh = -20;

recordTime = 2; %update to match SEQRun.m parameter
audioMode = 'soundsc';  %%GUI does not work with audioplayer, use soundsc as default

screen_pts = get(0,'ScreenSize');
pos = [screen_pts(1) screen_pts(2) screen_pts(3) screen_pts(4) - 45];

%Deterine experimental phase
if Training == 1
    expPhase = 'Training';
else
    expPhase = 'Test';
end

data = {};
done = 0;
button_quit = 0;

%Read in spec file
specFileName = strcat(subjName,'_',num2str(groupNum),'_',expPhase);
specFile = strcat('code\specFiles\',specFileName,'.txt');
[stimNums, stimSet] = textread(specFile,'%u %u');
numTrials = size(stimNums,1);
numStimTrained = 3; 
numTrialsPerStim = numTrials/numStimTrained; 

% %Read in log file
% logFileName = strcat(subjName,'_', num2str(groupNum),'_',expPhase, '_log.txt');
% logFile = fullfile(subjDir, logFileName);

%Read in stim file
stimFile = strcat(baseDir,'code/stim/StimNumList.txt');
[stimStrings] = textread(stimFile,'%s');

%Create matFile
matFileName = strcat(subjDir,'/',specFileName,'_',initials);
if ~isequal(matFileName(end - 3 : end), '.mat')
    matFileName = [matFileName, '.mat'];
end

    %Code for redo if redo passed in "varargin" field for function
    if exist('varargin','var') && ~isempty(strcmp(varargin, 'redo'))
        if exist(matFileName,'file')
            a_numTrials = 1:numTrials;
            disp('**** exist & redo ****')
        else
            error('Cannot find saved data file %s. Cannot proceed with mode redo.\n', matFileName);
        end
    else
        if exist(matFileName,'file')
            load(matFileName);
            a_numTrials = (size(data,2)) : numTrials;
            disp(strcat('**** using old coded file, starting @ trial #', num2str(a_numTrials(1)),' ****'));
        else
            a_numTrials = 1 : numTrials;
            disp('**** new data analysis ****')
        end
    end
    
%Main analysis loop ------------------------------------------------------    
GUI = input('Do you need to run scoring GUI? (1=yes, 0=no) ', 's');  %type 1 if you need to run through the scoring GUI (if this is your first time analyzing this subject)
    GUI = str2num(GUI);   
if GUI == 1

jj = 1;
while (jj <= length(a_numTrials)) && (button_quit == 0)
    ii = a_numTrials(jj);
    disp(strcat('TRIAL #: ',num2str(ii)));
    
    %open next elicited psuedoword
    stim = stimNums(ii);
    stimString = stimStrings{stim};
    string(stimString)
   
    if stimSet(ii) == 1 % set as TRAINED 
        cond = 'trained';
    elseif stimSet(ii) == 2 % set as NOVEL
        cond = 'novel';
    end
    
    data{ii}.trial = ii; %sets trial number
    data{ii}.cond = cond; %sets trained/novel 
    data{ii}.stim = stimString; %adds orthographic spelling of pseudoword to data file
    data{ii}.stimFileName = strcat(subjName,'_',num2str(groupNum),'_',expPhase,'_',num2str(ii),'_',stimString);  %.wav file name
    data{ii}.status = 0;  %mark trial is incomplete (not scored yet)
    
    %Read in audio recording for trial
    recordFile = strcat(subjDir,'/',subjName,'_',num2str(groupNum),'_',expPhase,'_',num2str(ii),'_',stimString,'.wav')
    [y, fs] = audioread(recordFile);  
    
        %Uncomment to play audio prior to opening GUI
        %         soundsc(y(1 : round(recordTime*fs)), fs);
    
    %GUI for initial visualization-------------------------------------------------
    SEQ_GUI(y, fs, recordTime, stimString,audioMode);
    uiwait;
    no_button_QUIT = 0;
    
        try  %save input from SEQ_GUI
            if buttonVals{1} == 1
                data{ii}.accuracy = 1;
            elseif buttonVals{1} == 2
                data{ii}.accuracy = 0;
            end
            
            if accuracyLowConfid ==1
                data{ii}.confidence = 0;  %if low confidence box ticked, mark 0
            else data{ii}.confidence = 1; %otherwise mark as confident
            end
                
        catch ME
            disp('Quitting...');
            data{ii}.status = 0;  %mark trial as incomplete
            no_button_QUIT = 1;
        end
    
    %calc onset and offset, through 2nd GUI-----------------------------------------
    if (button_quit == 0) && (data{ii}.accuracy == 1) && (no_button_QUIT == 0) %calculate for accurate trials, where accuracy saved without error

            winSize = round(fs * .0015); %sets winSize of 66 (about .15% of sampling rate) = 1.5 ms
            Incr = round(fs * .001); %sets Incr of 44 (about .1% of sampling rate) = 1 ms
            time = 0:1/fs:(length(y)-1)/fs; %creates time vector going from 0 to length of audio clip in s, in intervals of 1/fs
            iter = 1;
            speechOn = 0; %indicates speech Onset and speech Offset have not been set yet for this trial
            speechOff = 0;
            I = []; %creates Intensity variable to be filled below
            tm = []; %creates tm variable to be filled below
            BegWin = 1;
            EndWin = BegWin + winSize;  %moving window of 1.5 ms, advancing 1 ms each time (some overlap)
            
                %main Onset/Offset Loop
                while EndWin < length(y) || speechOff == 0  %loops until it reaches the end of audio file (y) OR sets offset time
                    dat = detrend(y(BegWin:EndWin, 1), 0);  %detrends mean from data (y, only in the specified window)
                    dat = convn(dat,[1;-.95]); %high-pass filter (removes low-frequency info); potentially remove! 
                    %dat = detrend(dat, 0); %detrends mean from dat, redundant?
                    int = sum(dat.^2); %sum of dat squared
                    I(iter) = 20*log10(int/.0015); %000015;  calculates I (dB) for this window; /.0015 finds mean of squared
                    tm(iter) = time(BegWin); %sets time for the start of the window

                    % checks for following conditions for Speech Onset:
                    %1. Iter has passed the  minimum onDur # of seconds; %2. speechOnset hasn't already been set
                    %3. number of samples exceeding Intensity threshold is equal to OnDur # of seconds
                    %4. time in which iter beyond onDur is greater than 90 ms- cutpoint for anticipation errors/background noise 
                    if iter > OnDur && speechOn == 0 && length(find(I(iter-OnDur:iter) > onThresh)) == length(I(iter-OnDur:iter)) && tm(iter-OnDur) > .09
                        speechOn = 1; %marks that a speech onset has been set
                        speechOnTime = tm(iter-OnDur); %calculate onset time (onDur samples prior to current iteration, where it actually started)
                        EndWin = BegWin + round(fs * .010);  %creates larger window for speech offset calculations (10 ms instead)

                    %checks for following conditions for speechOffset:
                    %1. Iter greater than OffDur minimum (can't reach minimum until iter reaches that number)
                    %2. speechOn marked in prior step; %3. No speechOff marked yet
                    %4. no segment with I > offThresh for the length of OffDur
                    %5. time between OffDur and iter is at least 400 ms (minimum length of stimuli- may need to update
                    elseif iter > OffDur && speechOn == 1 && speechOff ==0 && isempty(find(I(iter-OffDur:iter) > offThresh)) == 1 && tm(iter-OffDur) - speechOnTime > .40
                        speechOff = 1;  %marks that speechOff has been set
                        speechOffTime = tm(iter-OffDur); %calculates the point of speechOff, OffDur# of samples prior to current iteration point
                    end

                    BegWin = BegWin + Incr; %moves the window forward 1 ms for next iter
                    EndWin = EndWin + Incr; 
                    iter = iter + 1;
                end
            
            %if while loop reaches end of audio without finding speech on/off set
            if (speechOn ~= 1)
                speechOnTime = 0; %sets speechOnTime as 0 if it could never be detected
            end
            if (speechOff ~= 1)
                speechOffTime = recordTime; %sets speechOffTime as end of recording if it could never be detected
            end
            
                %%Second GUI---------------------------------------------------
                guidat.hfig = figure('Position', pos);

                %TOP PLOT------------------------------------------------------
                yvis = y;
                guidat.hsp1 = subplot(3, 1, 1); plot(time, detrend(yvis, 0), 'k'); hold on;
                %title(['Token is ' char(StimList(i)) '  < press spacebar to continue >']);
                axis tight;
                ax = axis;

                if speechOn == 1 && speechOff == 1
                    line([speechOnTime speechOnTime], [ax(3) ax(4)], 'Color', 'k', 'LineWidth', 2.0);
                    line([speechOffTime speechOffTime], [ax(3) ax(4)], 'Color', 'k', 'LineWidth', 2.0);
                end

                %MIDDLE PLOT---------------------------------------------------
                guidat.hsp2 = subplot(3, 1, 2); plot(tm, I, 'k'); hold on;
                bx = axis;

                if speechOn == 1 && speechOff == 1
                    line([speechOnTime speechOnTime], [bx(3) bx(4)], 'Color', 'k', 'LineWidth', 2.0);
                    line([speechOffTime speechOffTime], [bx(3) bx(4)], 'Color', 'k', 'LineWidth', 2.0);
                end
                axis([ax(1) ax(2) bx(3) bx(4)]);
            
                %BOTTOM PLOT---------------------------------------------------

                 %alternate spectrogram code
                 %nwin = 512; % samples  %noverlap = 256; %samples  %nfft = 512; %samples
                 %spectrogram(yvis, nwin, noverlap, nfft, fs, 'yaxis');
                 %ylim([0 4000]);

                guidat.hsp3 = subplot(3, 1, 3); hold on;
                show_spectrogram(y, fs, 'noFig');    
                xlabel('Time (s)');
                ylabel('Frequency (Hz)');
            
                %mark SpeechOn/Offset Times on spectrogram
                cx =axis;
                if speechOn == 1 && speechOff == 1
                    line([speechOnTime speechOnTime], [cx(3) cx(4)], 'Color', 'k', 'LineWidth', 2.0);
                    line([speechOffTime speechOffTime], [cx(3) cx(4)], 'Color', 'k', 'LineWidth', 2.0);
                end

                guidat.hLineOn = [NaN, NaN, NaN];
                guidat.hLineEnd = [NaN, NaN, NaN];
            
            %Checks if trial was marked as correct ("status")
            if data{ii}.status == 0 % Silence or Unusable (unrecognizable) --> no onset / offset labeling is necessary
                set(gcf, 'CurrentAxes', guidat.hsp1);
                title('No onset / offset labeling is needed since this trial is marked as silence or unusable', 'Color', 'k', 'FontSize', 14);
                drawnow;
                pause(2);
                title('', 'FontSize', 12, 'Color', 'k');

                data{ii}.duration = 0;
                data{ii}.rt = 0;
            else %for correct trials
                while 1
                    %display menu with analysis choices
                    accept = menu('Select', 'Accept', 'Edit', 'Play Segment');

                    switch accept
                        case 1  %Accept RMS-generated on/off times
                            data{ii}.rt = speechOnTime;
                            data{ii}.duration = speechOffTime-speechOnTime;
                            break;
                            
                        case 2  %Edit RMS-generated on/off times
                            bTimeLabelsOkay = 0; %mark TimeLabels as wrong
                             
                                while ~bTimeLabelsOkay  %loop until TimeLabels fixed
                                    %input times
                                    set(0, 'CurrentFigure', guidat.hfig);
                                    set(gcf, 'CurrentAxes', guidat.hsp1);
                                    ys = get(gca, 'YLim');

                                    for j0 = 1 : length(guidat.hLineOn)
                                        if ~isnan(guidat.hLineOn(j0))
                                            delete(guidat.hLineOn(j0));
                                        end
                                    end
                                    for j0 = 1 : length(guidat.hLineEnd)
                                        if ~isnan(guidat.hLineEnd(j0))
                                            delete(guidat.hLineEnd(j0));
                                        end
                                    end

                                    title('Set the onset time', 'Color', 'b'); drawnow;
                                    coord1 = ginput(1);

                                    set(gcf, 'CurrentAxes', guidat.hsp1);
                                    guidat.hLineOn(1) = plot(repmat(coord1(1), 1, 2), get(gca, 'YLim'), 'b--');
                                    set(gcf, 'CurrentAxes', guidat.hsp2);
                                    guidat.hLineOn(2) = plot(repmat(coord1(1), 1, 2), get(gca, 'YLim'), 'b--');
                                    set(gcf, 'CurrentAxes', guidat.hsp3);
                                    guidat.hLineOn(3) = plot(repmat(coord1(1), 1, 2), get(gca, 'YLim'), 'b--');
                                    set(gcf, 'CurrentAxes', guidat.hsp1);

                                    numResp_on = coord1(1);  %Save coordinate for mouse click (manually marked onset)

                                    title('Set the offset time', 'Color', 'b'); drawnow;
                                    coord2 = ginput(1);

                                    set(gcf, 'CurrentAxes', guidat.hsp1);
                                    guidat.hLineEnd(1) = plot(repmat(coord2(1), 1, 2), get(gca, 'YLim'), 'b-');
                                    set(gcf, 'CurrentAxes', guidat.hsp2);
                                    guidat.hLineEnd(2) = plot(repmat(coord2(1), 1, 2), get(gca, 'YLim'), 'b-');
                                    set(gcf, 'CurrentAxes', guidat.hsp3);
                                    guidat.hLineEnd(3) = plot(repmat(coord2(1), 1, 2), get(gca, 'YLim'), 'b-');
                                    set(gcf, 'CurrentAxes', guidat.hsp1);

                                    numResp_end = coord2(1); %Save coordinate for mouse click (manually marked onset)

                                    set(gcf, 'CurrentAxes', guidat.hsp1);
                                    set(gca, 'YLim', ys);

                                    %Confirm that manually marked speech onset occurs before end of speech
                                    bTimeLabelsOkay = (numResp_end > numResp_on);
                                    if ~bTimeLabelsOkay
                                        title('The onset and offset times you set are incorrect. Try again...', 'Color', 'r');
                                        drawnow;
                                        pause(1);
                                    else
                                        title('', 'Color', 'b'); drawnow;
                                    end
                                end
                            
                            data{ii}.durationManual = 1;  %test and update marker of manual correction for count of trials changed
                            speechOnTime = numResp_on; %Replace manual measurements with automatic measurement
                            speechOffTime = numResp_end; 
                            title('Click ACCEPT to keep or EDIT to change manual measurements.'); drawnow; 
                            pause(1); %then returns to main menu (accept), where accept will add duration to data structure
                            
                        case 3 % Select and play
                            set(0, 'CurrentFigure', guidat.hfig);
                            set(gcf, 'CurrentAxes', guidat.hsp1);
                            ys = get(gca, 'YLim');
                            
                            green = [0, 0.5, 0];
                            title('Set beginning of sound', 'Color', green); drawnow;
                            coord1 = ginput(1);
                            set(gcf, 'CurrentAxes', guidat.hsp1);
                            guidat.hPBLine0 = plot(repmat(coord1(1), 1, 2), ys, '--', 'Color', green);
                            drawnow;
                            
                            title('Set end of sound', 'Color', green); drawnow;
                            coord2 = ginput(1);
                            set(gcf, 'CurrentAxes', guidat.hsp1);
                            guidat.hPBLine1 = plot(repmat(coord2(1), 1, 2), ys, '-', 'Color', green);
                            
                            drawnow;
                            
                            title('', 'Color', 'b'); drawnow;
                            
                            
                            ysnip = y(time >= coord1(1) & time < coord2(1));

                                %play audio (if segment is selected)
                                if ~isempty(ysnip)
                                        soundsc(ysnip, fs);
                                else
                                    fprintf(1, 'WARNING: the selected audio appears to be empty. It will not be played.\n');
                                end
                            
                            pause(0.5);
                            
                            delete(guidat.hPBLine0);
                            delete(guidat.hPBLine1);
                    end  %end of "accept" GUI
                end
            end
        close;    %close GUI        
    end
        
    %Advance jj count to repeat main analysis loop for next trial 
    data{ii}.status = 1; %mark trial as scored prior to moving to next trial
    jj = jj + 1;
    
end
save(matFileName, 'data');

fprintf(1, 'Results saved to file %s\n', matFileName);

else
    load(matFileName);  %if GUI scoring skipped, load previously generated matFileName and proceed to statistics
end

%Within-subject desriptive statistics
statistics = input('Do you want to proceed with within-subject descriptive statistics at this time? (1=yes, 0=no) ', 's');  %type 1 if you need to run through the praat script if this is your first time analyzing this subject
    statistics = str2num(statistics);
    
if statistics ==1
    
numSDs = 3; %within how many SDs must a measure be to be included in the analysis
numTrialsFirstLast = 5; %how many trials to average over for first/last analyses

%count = 0;  
    
    %CALC MEAN, SD, AND MIN, FOR NOVEL&TRAINED IN TEST -------------------------------------------------
    if Training == 0 %select if novel-trained statistics should be completed (test phase)
        countTrained = 0; %count illegal  %what do these variables do?
        countNovel = 0; %count legal

        %Pre-allocate variables, with num trained/novel trials
        trainedRT = zeros(1, numTrials/2);  
        trainedDur = zeros(1, numTrials/2);
        trainedAcc = zeros(1, numTrials/2); 
        novelRT = zeros(1, numTrials/2);
        novelDur = zeros(1, numTrials/2);
        novelAcc = zeros(1, numTrials/2); %?
        
        for ii = 1:length(numtrials) %loop through all trials 
            if data(ii).duration > 0  %if duration marked
                if data(ii).accuracy > 0 

                    if strcmp(data(ii).cond, 'novel')
                        countNovel = countNovel + 1;
                        novelRT(countNovel) = data(ii).rt;
                        novelDur(countNovel) = data(ii).duration;
                        novelAcc(countNovel) = data(ii).accuracy;
                        %i_end(countNovel) = data(ii).rt + data(ii).duration;
                    else
                        countTrained = countTrained + 1;
                        trainedRT(countTrained) = data(ii).rt;
                        trainedDur(countTrained) = data(ii).duration;
                        trainedAcc(countTrained) = data(ii).accuracy;
                        %l_end(countTrained) = data(ii).rt + data(ii).duration;
                    end
                end
            end
        end
        
        %Calculate means and SD
        t_RT_mean = mean(nonzeros(trainedRT));
        t_RT_SD = std(nonzeros(trainedRT));
        n_RT_mean = mean(nonzeros(novelRT));
        n_RT_SD = std(nonzeros(novelRT));
        t_dur_mean = mean(nonzeros(trainedDur));
        t_dur_SD = std(nonzeros(trainedDur));
        n_dur_mean = mean(nonzeros(novelDur));
        n_dur_SD = std(nonzeros(novelDur));
        t_acc_mean = mean(nonzeros(trainedAcc)); %update! remove nonzeros?
        t_acc_SD = std(nonzeros(trainedAcc)); %remove nonzeros?
        n_acc_mean = mean(nonzeros(novelAcc)); %remove nonzeros?
        n_acc_SD = std(nonzeros(novelAcc)); %remove nonzeros?
        
        %Find outliers
        n_RT_out = n_RT_mean + numSDs*n_RT_SD;
        t_RT_out = t_RT_mean + numSDs*t_RT_SD;
        n_dur_out = n_dur_mean + numSDs*n_dur_SD;
        t_dur_out = t_dur_mean + numSDs*t_dur_SD;
        
        %PLOTS
        %Utterance Duration (UPDATE)------------------------------------------------------
        %------------------------------------------------------------------------
        % subplot(4,1,2); hold on; 
        %plot((1:length(trainedDur)),trainedDur,'r');
        % hold on; plot((1:length(novelDur)),novelDur,'b');
        % title('Utterance Duration');
        
        %Accuracy (UPDATE)----------------------------------------------------------------
        %------------------------------------------------------------------------
        % subplot(3,1,3); hold on; plot((1:60),1-illegal_errors,'r');
        % hold on; plot((1:60),1-legal_errors,'b');
        % title('Accuracy');
        % ylabel('Percent correct');
        % xlabel('Repetition');

    %CALC MEAN, SD, AND MIN, TRAINING-------------------------------------------------
     else  %runs statistics on training phase (first five-last five comparisons)

        %Pre-allocate variables, with numTrials
        trainedRT = zeros(1, numTrials);  
        trainedDur = zeros(1, numTrials);
        initials = zeros(numTrialsFirstLast,size(unique(stimNums))); %first 5 trials of each stim
        finals = zeros(numTrialsFirstLast,size(unique(stimNums)));  %last 5 trials of each stim
        
        for ii = 1:length(numtrials)
            num = data(ii).stimNum;
            if data(ii).duration > 0
                if data(ii).accuracy > 0  

                    if data(ii).count == numTrialsPerStim   %identify last trial (180/3 = 60 reps of each stim)
                        finals(1,num) = data(ii).duration;
                    elseif data(ii).count == numTrialsPerStim -1
                        finals(2,num) = data(ii).duration;
                    elseif data(ii).count == numTrialsPerStim -2
                        finals(3,num) = data(ii).duration;
                    elseif data(ii).count == numTrialsPerStim -3
                        finals(4,num) = data(ii).duration;
                    elseif data(ii).count == numTrialsPerStim -4
                        finals(5,num) = data(ii).duration;
                    elseif data(ii).count == 1  %checks for 1st 5 accurate trials
                        initials(1,num) = data(ii).duration;
                    elseif data(ii).count == 2
                        initials(2,num) = data(ii).duration;
                    elseif data(ii).count == 3
                        initials(3,num) = data(ii).duration;
                    elseif data(ii).count == 4
                        initials(4,num) = data(ii).duration;
                    elseif data(ii).count == 5
                        initials(5,num) = data(ii).duration;
                    end

                        %count = count + 1;   %?
                        trainedRT(ii) = data(ii).rt;
                        trainedDur(ii) = data(ii).duration;
                        %i_end(ii) = data(ii).rt + data(ii).duration;
                    
                end
            end
        end
        
        %Calculate means and SD
        t_RT_mean = mean(nonzeros(trainedRT));
        t_RT_SD = std(nonzeros(trainedRT));
        t_dur_mean = mean(nonzeros(trainedDur));
        t_dur_SD = std(nonzeros(trainedDur));
        t_acc_mean = mean(nonzeros(trainedAcc));  %Update accuracy- remove nonzeros?
        t_acc_SD = std(nonzeros(trainedAcc));
        
        % final_means = mean(finals);
        % hold on;
        % bar(final_means);
        % errorbar((1:14),final_means,std(finals));
       
    end
    
   
  
%UPDATE- Create structure to save statistics!




end


