function [hFig, hSpect] = SEQ_GUI(y, fs, recordTime, stimString,audioMode)
    global buttonVals done
    global accuracyLowConfid
    global button_quit
    
    hSpect = figure('Visible', 'on', 'Menu','none', 'Name',stimString, 'Resize','on', 'Position',[100 350 1000 200]);    
    subplot('Position', [0.05, 0.2, 0.9, 0.775]);
    movegui(hSpect, 'northwest');
    show_spectrogram(y, fs, 'noFig');    
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(stimString);
    
    hFig = figure('Visible','off', 'Menu','none', 'Name',stimString, 'Resize','on', 'Position',[100 100 500 500]);    
    movegui(hFig, 'center');          %# Move the GUI to the center of the screen      

    errorBtnGrp = uibuttongroup('Position',[0 0.4 0.8 0.75], 'Units','Normalized','Title','ACCURACY');
    uicontrol('Style','Radio', 'Parent',errorBtnGrp, 'HandleVisibility','off', ...
        'Position',[15 270 135 30], 'String','Accurate', 'Tag','accurate')
    uicontrol('Style','Radio', 'Parent',errorBtnGrp, 'HandleVisibility','off', ...
        'Position',[15 240 135 30], 'String','Error', 'Tag','error')
    
    confidenceGrp = uibuttongroup('Position',[0 0.2 0.8 0.2], 'Units','Normalized','Title','RATING CONFIDENCE');
    cb_lowConfid_accuracy = ...
        uicontrol('Style', 'Checkbox', 'Parent', confidenceGrp, 'HandleVisibility', ...
        'off', 'Position', [15 5 160 30], 'String', 'Accuracy - low confidence', 'Tag','fluent');
    
	uicontrol('Style','pushbutton', 'String','Play', 'Position',[420 150 60 50], 'Callback',{@button2_callback, audioMode})
    uicontrol('Style','pushbutton', 'String','Submit', 'Position',[420 90 60 50], 'Callback',{@button_callback})
    uicontrol('Style','pushbutton', 'String','Quit', 'Position',[420 30 60 50], 'Callback',{@button3_callback})
    
    set(hFig, 'Visible','on')        %# Make the GUI visible

%% callback function
function [returnVars] = button_callback(src, ev)
    a = get(get(errorBtnGrp, 'SelectedObject'),'Tag');
    switch a
        case 'accurate'
            %disp('accurate');
            buttonVals{1} = 1;
        case 'error'
            buttonVals{1} = 2;
    end
    
    accuracyLowConfid = get(cb_lowConfid_accuracy, 'Value');

    display(strcat('Submitting: ', a,'...'));
    done = 1;
    %close(gcbf);
    close all;
end

%% play sound
function [returnVars] = button2_callback(src, ev, audioMode)
%     if isequal(audioMode, 'soundsc')
          soundsc(y(1:round(recordTime*fs)), fs);
%      else
%         ap = audioplayer(y(1:round(recordTime*fs)), fs);
%         play(ap, 1);
%    end
end

function [returnVars] = button3_callback(src, ev)
    %done = 1;
    button_quit = 1;
    close all;
end
end