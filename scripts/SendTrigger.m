function SendTrigger( TrialStruct, TriggerCode )
% SendTrigger
% Send TriggerCode as a binary number.
% PortIdx is ignored in this version of the function.
% TrialStruct has the port setup in it via Setup_DAQ_STIM .

%% Set up trigger code.
% Reverse trigger code.
TriggerCode = fliplr( TriggerCode );

% Write string.
TriggerCode = strrep(num2str(TriggerCode), ' ', '');

% Convert to decimal representation.
TriggerCode = bin2dec(TriggerCode);

%% Write out.
io64(TrialStruct.portObj,TrialStruct.portAddress,TriggerCode);

