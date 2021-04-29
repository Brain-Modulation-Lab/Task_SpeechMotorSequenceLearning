%function pilotAnalysis_practice(subjName, groupNum, specFileName, testType)
%e.g. pilotAnalysis_practice('pilot001', 1, 'practicea', 'run1')
function pilotAnalysis_alt(subjName, groupNum, expPhase)
%sample input pilotAnalysis_alt('SEQ_Pilot2', 2, 0), to evaluate SEQ_Pilot 2
%(member of group 2) test phase

cd C:\speechres\SEQ-FTD\
addpath C:\speechres\SEQ-FTD\code\scripts
addpath C:\speechres\SEQ-FTD\code\scripts\analysis
addpath C:\speechres\SEQ-FTD\code\stim   
addpath C:\speechres\SEQ-FTD\code\specFiles  
subjDir = strcat('sub-', subjName);

recordTime = 2;

%Create trials data structure
trials(1).stim = '';
trials(1).stimFileName = '';
trials(1).stimNum = 0;
trials(1).duration = [];
trials(1).rt = 0;
trials(1).trial = 0;
trials(1).count = 0;
trials(1).status = -1;
trials(1).cond = '';

counts = zeros(1,8);  %%DELETE?
if nargin < 2
    error('Must provide required input parameters subjName, groupNum, expPhase');
end

screen_pts = get(0,'ScreenSize');
pos = [screen_pts(1) screen_pts(2) screen_pts(3) screen_pts(4) - 45];

%Deterine experimental phase
if expPhase == 1
    expPhase = 'Training';
else
    expPhase = 'Test'
end

%Read in spec file
specFileName = strcat(subjName,'_',num2str(groupNum),'_',expPhase);
specFile = strcat('code\specFiles\',specFileName,'.txt');
[stimNums, stimSet] = textread(specFile,'%u %u');
%[stimNums waits] = textread(specFile,'%d %d'); %old code from MP
%stim to be presented, file name under which recorded is saved, ISI
%clear waits;

numTrials = size(stimNums,1);
disp(numTrials);
stimList = textread('stim\StimNumList.txt','%s');

% %Set stimTrained and stimNovel for each group- Necessary?? Does stimSet
% %address this? 
% if groupNum == 1  %numbers refer to stimuli in stim directory
%     stimTrained = [28 30 31];
%     stimNovel = [3 5 9 11 12 17 20 22 23];
% elseif groupNum == 2
%     stimTrained = [11 17 23];
%     stimNovel = [3 5 9 12 20 22 28 30 31];
% elseif groupNum == 3
%     stimTrained = [3 5 9];   
%     stimNovel = [11 12 17 22 23 28 30 31];
% elseif groupNum == 4
%     stimTrained = [12 20 22];  
%     stimNovel = [3 5 9 11 17 23 28 30 31];
% else
%     error('Invalid input parameters'); 
% end

% %specific # stim to be learned by group
% groupList = [1:4]+(groupNum-1)*4;
% if mod(groupNum,2) == 0
%     legal = [33:36];
% else
%     legal = [37:40];
% end
% groupList = horzcat(groupList,legal);
% disp(groupList);



OnDur = 10;  % this value is in ms and controls how long the intensity should exceed the threshold to be considered an onset
onThresh = -20;  % onset threshold

OffDur = 75;
offThresh = 0;

count = 1;
stimOn = 0;
speechOn = 0;
speechOff = 0;
iter = 1;
term = 0;

for ii = 1:numTrials
    disp(ii);
    %open next elicited psuedoword
    %stimNums(ii): 1-8, order of trials
    %groupList(stimNums(ii)): 1-32, stims appropriate for each group 
    %stimList(groupList(stimNums(ii))): actual pseudowords
    
    stim = char(stimList(stimNums(ii)));
%     counts(1,stimNums(ii)) = counts(1,stimNums(ii)) + 1;
%     if stimNums(ii) <=4
%         condString = 'illegal';
%     else
%         condString = 'legal';
%     end
    trialNumString = num2str(ii);
    recordFile = strcat(subjDir,'/',subjName,'_',num2str(groupNum),'_',expPhase,'_',num2str(ii),'_',stim,'.wav') %fix stimstring!
    disp(recordFile);
    disp(stimSet(ii));  %clean up- convert to plain text word? Or add "stim set = " prior to number
    %disp(condString);
    [y, fs] = audioread(recordFile);
    %soundsc(y(1:round(1.5*fs)), fs);
    soundsc(y(1:round(recordTime*fs)), fs);  %where 2 = length of recording in seconds
    
    index2 = 1;
    while index2 == 1
        k = menu(stim, 'PLAY', 'ERROR', 'CALC', 'EXIT');
        if k == 1
            soundsc(y(1:round(recordTime*fs)), fs);
        elseif k == 2
            trials(ii).stim = stim;
            trials(ii).stimFileName = recordFile;
            trials(ii).stimNum = stimNums(ii);
            trials(ii).duration = 0;
            trials(ii).rt = 0;
            trials(ii).trial = ii;
            trials(ii).count = counts(1,stimNums(ii));
            trials(ii).status = 0;
            trials(ii).cond = condString;
            index2 = 0;
        elseif k == 4
            term = 1;
            index2 = 0;
        elseif k == 3
            winSize = round(fs * .0015);
            Incr = round(fs * .001);   
            time = 0:1/fs:(length(y)-1)/fs;
            %noWins = length(winSize:Incr:(length(y)-winSize));
            iter = 1;
            I = [];
            tm = [];
            BegWin = 1;
            EndWin = BegWin + winSize;
            while EndWin < length(y) %ii = 1:noWins
                dat = detrend(y(BegWin:EndWin, 1), 0);        
                dat=convn(dat,[1;-.95]);
                dat = detrend(dat, 0);
                int = sum(dat.^2);
                I(iter) = 20*log10(int/.0015); %000015
                tm(iter) = time(BegWin);
                if iter > OnDur && speechOn == 0 && length(find(I(iter-OnDur:iter) > onThresh)) == length(I(iter-OnDur:iter)) && tm(iter-OnDur) > .09
                    disp('***');
                    speechOn = 1;
                    speechOnTime = tm(iter-OnDur);
                    %endTm = round(speechOnTime*fs);
                    EndWin = BegWin + round(fs * .010);
                elseif iter > OffDur && speechOn == 1 && isempty(find(I(iter-OffDur:iter) > offThresh)) == 1 && tm(iter-OffDur) - speechOnTime > .40
                    disp('###');
                    speechOff = 1;
                    speechOffTime = tm(iter-OffDur);
                    %offTm = round(speechOffTime*fs);
                    %winSize = round(fs * .0015);
                end
                
                %once speechOn and Off marked- display with options for
                %Take v Reject
                if speechOn == 1 && speechOff == 1
                    figure('Position', pos); 
                    subplot(2, 1, 1), plot(time, detrend(y, 0), 'k'); hold on;
                    %title(['Token is ' char(StimList(i)) '  < press spacebar to continue >']);
                    axis tight;
                    ax = axis;
                    line([speechOnTime speechOnTime], [ax(3) ax(4)], 'Color', 'k', 'LineWidth', 1.0);
                    line([speechOffTime speechOffTime], [ax(3) ax(4)], 'Color', 'k', 'LineWidth', 1.0);
                    subplot(2, 1, 2), plot(tm, I, 'k'); hold on;
                    bx = axis;
                    line([speechOnTime speechOnTime], [bx(3) bx(4)], 'Color', 'k', 'LineWidth', 1.0);
                    line([speechOffTime speechOffTime], [bx(3) bx(4)], 'Color', 'k', 'LineWidth', 1.0);
                    axis([ax(1) ax(2) bx(3) bx(4)]);

                    accept = menu('Select', 'Take', 'Reject');
                    if accept == 1
                        trials(ii).stim = stim;
                        trials(ii).stimFileName = recordFile;
                        trials(ii).stimNum = stimNums(ii);
                        trials(ii).duration = [speechOffTime-speechOnTime];
                        trials(ii).rt = speechOnTime;
                        trials(ii).trial = ii;
                        %trials(ii).count = counts(1,stimNums(ii));%%UPDATE
                        trials(ii).status = 1;
                        trials(ii).cond = condString;
                    elseif accept == 2
                        trials(ii).stim = stim;
                        trials(ii).stimFileName = recordFile;
                        trials(ii).stimNum = stimNums(ii);
                        trials(ii).duration = 0;
                        trials(ii).rt = 0;
                        trials(ii).trial = ii;
                        trials(ii).count = counts(1,stimNums(ii));
                        trials(ii).status = 0;
                        trials(ii).cond = condString;
                    end
                    
                    %reset following GUI
                    close;
                    count = count + 1;
                    stimOn = 0;
                    speechOn = 0;
                    speechOff = 0;
                    BegWin = BegWin + round(fs*2.0);  %UPDATE?
                    EndWin = EndWin + round(fs*2.0);  %UPDATE?
                    iter = 0;
                    I = [];
                    tm = [];
                    break;
                
                end
                
                %move Window forward 1 ms for next iteration of while loop
                BegWin = BegWin + Incr;
                EndWin = EndWin + Incr;
                iter = iter + 1;
            end
            
            if length(trials) < ii
                trials(ii).stim = stim;
                trials(ii).stimFileName = recordFile;
                trials(ii).stimNum = stimNums(ii);
                trials(ii).duration = 0;
                trials(ii).rt = 0;
                trials(ii).trial = ii;
                %trials(ii).count = counts(1,stimNums(ii)); %%UPDATE
                trials(ii).status = 0;
                trials(ii).cond = condString;
            end
            index2 = 0;
        end
    end
    if term == 1
        break
    end
    speechOn = 0;
    speechOff = 0;
    iter = 0;
    I = [];
    tm = [];
%     end
end
%matFileName = strcat(subjName,'\trials_',testType);
matFileName = strcat(subjDir,'/',subjName,'_',expPhase);
save(matFileName, 'trials');

