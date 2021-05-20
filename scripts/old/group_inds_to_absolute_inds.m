%%%% rename all files with specified extension in working directory so that
%%%% index within group is replaced with absolute index
%
% a file named (e.g.) '4.2 abcd.wav', where each group has 4 files, will
% be renamed '14_abcd.wav' (because 4*[4-1] + 2 = 14)
%
% used to match stim filename convention expected by stim randomization script
%
%%%% updated 2021/3/17 by Andrew Meier

extension_string = '.wav'; % rename all files with this extension
files_per_group = 4; 
offset = 36; % add this value to all output indices

checkval = input('Files in current directory will be renamed.... are you sure? (y=yes)','s');
if ~strcmp(checkval,'y')
    error('quitting')
end

dd = struct2table(dir); 
dd = dd(contains(dd.name, '.wav'),:);
for ifile = 1:height(dd)
    ind1 = str2num(dd.name{ifile}(1));
    ind2 = str2num(dd.name{ifile}(3));
    new_ind = offset + files_per_group * [ind1-1] + ind2; 
    cropped_filename = dd.name{ifile}(5:end);
    new_filename = [num2str(new_ind), '_', cropped_filename];
    if new_ind < 10
        new_filename = ['0', new_filename]; % make sure number in filename is 2 digits
    end
    movefile(dd.name{ifile}, new_filename)
end

    