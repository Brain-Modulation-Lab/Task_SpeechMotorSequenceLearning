% stimListRandomizer:  creates a randomized trial list from the trial 
% indices specified in the imported trial list tables
%
%           stimListRandomizer(subjName, groupNum, experiment_phase, nblocks) 
%
% Inputs: 
%   1. subj_name = name of subject
%   2. group_num = stimulus group subject is assigned to (1-5); make sure subject has same group across all 3 experimental phases
%   3. experiment_phase = 0 (familiarization), 1 (practice), or 2 (testing)
%   4. nblocks = number of times the entire stim set is repeated (in a new randomized order)


% The first column of .txt output is the stimulus number; 
% second is stimulus type (1 for trained non-native; 2 for novel non-native; 3 for native);
% third column indicates whether trial is a stop trial (1 = stop, 0 = not stop); 
% fourth column indicates (for stop trials only) what the stop latency is in milliseconds

%Code developed by Hilary Miller and Frank Guenther
%%% modified for DBS by Andrew Meier 2021-3-31

function stimListRandomizer_DBS(subj_name, group_num, experiment_phase, nblocks) 

% for training ONLY, specify the range of latencies between fixation cross appearance and STOP signal
training_stoptrial_latencies_ms = [100:50:400]; % milliseconds

% for familiarization and testing, set a fixed stoptrial latency
familiarization_stoptrial_latency_ms = 200; % milliseconds 
testing_stoptrial_latency_ms = 200; % milliseconds

addpath C:\speechres\SEQ-DBS\code\specFiles  

% select experimental phase, load stim index data
if experiment_phase == 0
    exp_phase_name = 'Familiarization'; 
    stimtable = readtable('C:\speechres\SEQ-DBS\stim_group_lists_familiarization.xlsx');
elseif experiment_phase == 1
    exp_phase_name = 'Training';
    stimtable = readtable('C:\speechres\SEQ-DBS\stim_group_lists_training.xlsx');
elseif experiment_phase == 2
     exp_phase_name = 'Test';
    stimtable = readtable('C:\speechres\SEQ-DBS\stim_group_lists_test.xlsx');
else
    error('experiment_phase must equal 0 (familiarization), 1 (practice), or 2 (testing)')
end
    
numTrialsPerBlock = height(stimtable); 

% for stim entries with multiple indices listed, randomly pick one index
stim_inds_from_xlsx = stimtable{:,['group',num2str(group_num)]}; 
stim_inds_selected = NaN(height(stimtable),1); % stim indices to use after selecting from random options
for irow = 1:length(stim_inds_from_xlsx)
    if iscell(stim_inds_from_xlsx)
        this_row_vals = str2num(stim_inds_from_xlsx{irow});
    elseif isnumeric(stim_inds_from_xlsx) % for columns with no data imported as strings
        this_row_vals = stim_inds_from_xlsx(irow);
    end
    nvals_this_row = length(this_row_vals);
    if nvals_this_row == 1
        stim_inds_selected(irow) = this_row_vals;
    elseif nvals_this_row > 1
        selected_index_this_row = randperm(nvals_this_row, 1); % randomly pick one of the listed stim indices)
        stim_inds_selected(irow) = this_row_vals(selected_index_this_row);
    end
end

% trialList column 1 = stim identity index, column 2 = condition.... non-native learned [1], non-native trained [2], native [3] 
trialList = [stim_inds_selected, stimtable.condition, stimtable.stop_trial];

%Set output file name
specFileName = strcat(subj_name, '_', num2str(group_num), '_', exp_phase_name);
specFile = strcat('C:\speechres\SEQ-DBS\code\specFiles\',specFileName,'.txt');

% Next, randomly permute the trials and check to see if they
% meet all criteria for consecutive trials. If not, then redo
% until a good randomized order is achieved.
trial_list_all_blocks = [];
for iblock = 1:nblocks % create separarate randomized versions of the trial list within each block, then concatenate
    %%% familiarization - don't randomize, use order specified in stim_group_list file
    if strcmp(exp_phase_name, 'Familiarization')
        trials_this_block = trialList; 
    end
        
    %%% training and testing - randomize order under certain limitations
    if any(strcmp(exp_phase_name, {'Training','Test'}))
        badOrder = 1;
        while (badOrder > 0)
            indices = randperm(numTrialsPerBlock);
            trials_this_block = zeros(numTrialsPerBlock, size(trialList,2));
            badOrder = 0;
            for trialIndex = 1:numTrialsPerBlock
                trials_this_block(trialIndex,:) = trialList(indices(trialIndex),:);

                % make sure the block doesn't begin with a STOP trial
                if trialIndex == 1 && trials_this_block(trialIndex, 3) % if it's the first trial and a STOP trial
                    badOrder = 1; 
                end

                if trialIndex > 1
                    % check for consecutive STOP trials 
                    if trials_this_block(trialIndex,3) == 1 && trials_this_block(trialIndex-1,3) == 1 % if this trial and the preceding trial are STOP
                        badOrder = 1; 
                    end
                    % Check for consecutive same stim trials
                    if trials_this_block(trialIndex,1) == trials_this_block(trialIndex-1,1)
                        badOrder = 1;
                    end
                end

               if trialIndex > 2
                    %For test phase, check for 3 consecutive same-condition trials (non-native learned [1] vs. non-native novel [2] vs. native [3])
                    if strcmp(exp_phase_name, 'Test')
                        if [trials_this_block(trialIndex,2) == trials_this_block(trialIndex-1,2)] && ... % this trial == previous trial and....
                                [trials_this_block(trialIndex,2) == trials_this_block(trialIndex-2,2)] % .... this trial == two trials back
                            badOrder = 1;
                        end
                    end
               end
            end
        end
    end
%     trialListRandom % Print trial list to screen for quick review
    trial_list_all_blocks = [trial_list_all_blocks; trials_this_block]; %%% add this block to the full list
end

%% generate STOP trial latencies
ntrials_total = size(trial_list_all_blocks,1);
total_stoptrials = nnz(trial_list_all_blocks(:,3)); % get total number of STOP trials
is_stoptrial = logical(trial_list_all_blocks(:,3)); 
trial_list_all_blocks(:,4) = zeros(ntrials_total,1); % add column for stop latency
switch exp_phase_name
    case 'Training' % test range of stop latencies for training
        n_stop_latencies = length(training_stoptrial_latencies_ms); 
        stop_latencies_expanded = repmat(training_stoptrial_latencies_ms, 1, total_stoptrials); % expand so we can sample from them
        stop_latency_inds = randperm(length(stop_latencies_expanded), total_stoptrials); % one STOP latency for each STOP trial
        stop_latencies_by_trial = stop_latencies_expanded(stop_latency_inds);
        trial_list_all_blocks(is_stoptrial,4) = stop_latencies_by_trial; % assign latencies to stop trials
    case 'Familiarization' % use fixed stop latency for familiarization
        trial_list_all_blocks(is_stoptrial,4) = familiarization_stoptrial_latency_ms; % assign latencies to stop trials
    case 'Test' % use fixed stop latency for familiarization
        trial_list_all_blocks(is_stoptrial,4) = testing_stoptrial_latency_ms; % assign latencies to stop trials
end
   
    %% save output into the specfile
fileID = fopen(specFile,'w');

for i = 1:size(trial_list_all_blocks,1)
    fprintf(fileID,'%u %u %u %u',trial_list_all_blocks(i,:)); % stim index, condition, is_stoptrial, stop trial latency
    if i < size(trial_list_all_blocks,1)
        fprintf(fileID,'\n');
    end
end

% % % fprintf(fileID,'%u %u',trial_list_all_blocks);

fclose(fileID);
% % % numTrialsPerBlock % Print number of trials
