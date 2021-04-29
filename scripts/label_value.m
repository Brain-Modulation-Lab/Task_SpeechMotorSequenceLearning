function [labelcode, value, label, valstr] = label_value(in1, in2)
% dictionary function to encode metadata in triggers
%
% Use as
%   labelcode = label_value(label)
%   [labelcode, value] = label_value(label, value)
%   [labelcode, value] = label_value(label, valstr)
%   [labelcode, value] = label_value('version')
%   [labelcode, ~, label] = label_value(labelcode)
%   [labelcode, value, label, valstr] = label_value(labelcode, value)
%
% label - char, Name of label. 
% value - int, value to be encoded
% labelcode - int, integer representation of label
% valstr - char, categorical level name represented by value

VERSION = 5;

label_dict = {...
    'unknown'       ,129,{};
    'version'       ,130,{};
    'hour'          ,144,{};
    'minute'        ,145,{};
    'second'        ,146,{};
    'subject_cohort',150,{'unknown','DM','EM','MG','test'}; 
    'subject_serie' ,151,{};
    'subject_number',152,{};
    'session'       ,160,{'unknown','test','training','preop','intraop','emu'};
    'task'          ,161,{'unknown','lombard','LMM','resting','sync','RRM','calibrate','SMSL'};
    'task_version'  ,162,{};
    'run'           ,163,{};
    };

if nargin == 0
  labelcode = label_dict;
  return
end
  
labelcode=[];
label=[];
value=[];
valstr=[];

if ischar(in1) %label value to code
    label = in1;
    label_idx = find(strcmpi(label,label_dict(:,1)),1);
    if isempty(label_idx)
        label_idx = 1;
        labelcode = 129; %unknown
    else
        labelcode = label_dict{label_idx,2};
    end
    if ~exist('in2','var')
        if strcmpi(label,'version')
            value = VERSION;
        end
    elseif ischar(in2)
        valstr=in2;
        value = find(strcmpi(valstr,label_dict{label_idx,3}),1);
        if isempty(value)
            warning('unknown label:%s value:%s',label,valstr)
            value = 0;
        end
    elseif isnumeric(in2)
        value = in2;
        if value > 127
            warning('value of %i for label %s is out of range, clipping to 127', value, label);
            value = 127;
        end
    else
        warning('unsupported type for in2')
        value = 0;
    end
    %code = 32768 + labelcode .* 256 + value;
    
elseif isnumeric(in1) %code to label value
    if in1 >= 256
        warning('value out of range')
    elseif in1 < 128
        warning('not a label code')
    else %in range 
        labelcode = in1;
        %value = mod(code,256);
        %labelcode = (code - value - 32768) ./ 256;
        label_idx = find(labelcode == [label_dict{:,2}],1);
        if isempty(label_idx)
            warning('unknown label for label_code==%i',labelcode)
            label_idx = 1;
            labelcode = 129; %unknown
        end
        label = label_dict{label_idx,1};
        levels = label_dict{label_idx,3};
        if ~exist('in2','var')     
            value=[];
            valstr=[];
        elseif ischar(in2)
            valstr = in2;
            if ~isempty(levels)
                match=strcmpi(valstr,levels);
                if sum(match)>0
                    value = find(match);
                else
                    value = 1; %unknown
                end
            end        
            
        elseif isnumeric(in2)
            value = in2;
            if ~isempty(levels)
                if value > numel(levels)
                    valstr = 'unknown';
                else
                    valstr = levels{value};
                end
            end
        end

    end
end
    
    

        


