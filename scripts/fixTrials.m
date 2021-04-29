function fixTrials(fileName)

load(fileName);

x = input('Trial #: ','s');
while ~strcmp(x,'q');
    num = str2num(x);
    disp(trials(num).stim);
    time = input('RT: ');
    trials(num).rt = time;
    dur = input('Duration: ');
    trials(num).duration = dur;
    x = input('Trial #: ','s');
end

save(fileName,'trials');