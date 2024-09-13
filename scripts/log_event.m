function log_event(file, digout, onset, dur, samp, trial_type, stim_file, val, event_name, flip_sync)

% log_events in BIDS compatible events.tsv format and send triggers through
% io64 mex library
% file:         open connection to events file
% digout:       structure with fields portObj and portAddress 
% onset:        float, onset time of event in seconds from time origin
% dur:          float, duration of the event in seconds. 
% samp:         uint, sample index on ripple system
% trial_type:   Primary categorisation of each trial to identify them as instances of the experimental conditions.
% stim_file:    Represents the location of the stimulus file presented at the given onset time.
% value:        Marker value associated with the event (e.g., the value of a TTL trigger that was recorded at the onset of the event).
% event_name:   Short name for the event
% flip_sync:    bool, screen flip sync signal level. 

%getting global time coordinate origin on first call
persistent t0
if isempty(t0)
    t0 = GetSecs() - seconds(timeofday(datetime('now'))); 
end

%setting defaults
if isempty(onset)
    onset = GetSecs();
end

if isempty(val)
    val = 0;
end

if ~isempty(digout) 
  io64(digout.portObj,digout.portAddress,val);
end

if isempty(dur)
    dur = 0;
end

if isempty(samp) 
    samp = 0;
end

if isempty(trial_type)
    trial_type = 'n/a';
end

if isempty(stim_file)
    stim_file = 'n/a';
end

if isempty(event_name)
    event_name = 'n/a';
end

fprintf(file,'%10.6f\t%6.6f\t%i\t"%s"\t"%s"\t%i\t"%s"\n',onset-t0,dur,samp,trial_type,stim_file,val,event_name);


