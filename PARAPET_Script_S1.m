%define variables
FOLDER = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_S1';
DATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_DATASETS';
ICADATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_ICA';
ERPDATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_ERP';
CNT = 'cnt';
SET = 'set';
ERP = 'erp';
SESSION = 'S1'; %change according to session number
LOWCUT = 0.5;
HIGHCUT = 50;
SAMPLER = 512;
EPOCHBEF = -200.0;
EPOCHAFT = 1000.0;
BINDESC = 'C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\bindescrip.txt';
ERPLOW = 30;
ERPBIN = 'bin3 = bin2 - bin1 label CS+ CS- difference';
LAT1 = 250.00; %start latency under study
LAT2 = 550.00; %end latency under study
%% ------------------------------------------

% Get list of files
filesEEG = dir(FOLDER);

%amount of files in folder
nFiles = length(filesEEG);
filesEEG = filesEEG(3:nFiles);
nFiles = length(filesEEG);

for pp = 1:nFiles  % will be able to run through multiple participants e.g. 1:90 or to nfiles for all
    try
    if contains(filesEEG(pp).name, CNT) & contains(filesEEG(pp).name, SESSION)
        ero = 'load error';   %set as different things throughout so we can see where the script stopped at for that pps to figure out what's going wrong      
        EEG = pop_loadeep_v4(sprintf(strcat(FOLDER,'/%s'),  filesEEG(pp).name));
    end

    %cuts data before_after first_last relevant event
    Eventt = {EEG.event(:).type}; 
    ero = 'cut error';
    eventIndexes = [find(strcmp(Eventt, '0020')), find(strcmp(Eventt, '0030')), find(strcmp(Eventt, '0035')), find(strcmp(Eventt, '0040')), find(strcmp(Eventt, '0050')), find(strcmp(Eventt, '0060')), find(strcmp(Eventt, '0070'))];
    eventIndexes = sort(eventIndexes); %usually in order anyway
    TimeOfFirstEvent = (((EEG.event(min(eventIndexes(:))).latency)/1000))-60;  
    TimeOfLastEvent = (((EEG.event(max(eventIndexes(:))).latency)/1000))+60;
    AcqTrials=length(eventIndexes);

    EEG = pop_select(EEG,'time',[TimeOfFirstEvent TimeOfLastEvent]);
    EEG = eeg_checkset(EEG);


    % pre-processing starts
    EEG.etc.eeglabvers = '2022.0'; % this tracks which version of EEGLAB is being used, you may ignore it
    EEG = eeg_checkset(EEG);

    %update channel locations
    EEG = pop_chanedit(EEG, 'lookup','Standard-10-5-Cap385.sfp');
    EEG = eeg_checkset(EEG);

    %rereference data to average
    EEG = pop_reref(EEG, []);
    EEG = eeg_checkset(EEG);

    %highpass and lowpass filter 0.5 50
    EEG = pop_eegfiltnew(EEG, 'locutoff', LOWCUT,'hicutoff', HIGHCUT,'plotfreqz',1);
    EEG = eeg_checkset(EEG);

    %resample data to 512Hz
    EEG = pop_resample(EEG, SAMPLER);
    EEG = eeg_checkset(EEG);

    % Keep original EEG.
    originalEEG = EEG;

    %clean raw data removes bad channels and then interpolate
    %remove bad channels
    EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.8,'LineNoiseCriterion',4,'Highpass','off','BurstCriterion',20,'WindowCriterion',0.25,'BurstRejection','off','Distance','Euclidian','WindowCriterionTolerances',[-Inf 7] );
    EEG = eeg_checkset(EEG);

    %save channels - use for notes
    ChanR = 0;
    channelsAfterRemove = [];
    for ii = 1 : length(EEG.chanlocs)
        ChanR = ChanR + 1;
        channelsAfterRemove = [channelsAfterRemove, string([' ' EEG.chanlocs(ChanR).labels ' ']) ];
    end

    %removed channel interpolation
    EEG = pop_interp(EEG, originalEEG.chanlocs, 'spherical');
    EEG = eeg_checkset(EEG);

    %gets channel list
    ChanR = 0;

    channelsBeforeRemove = [];
    for ii = 1 : length(EEG.chanlocs)
        ChanR = ChanR + 1;
        channelsBeforeRemove = [channelsBeforeRemove, [' ' EEG.chanlocs(ChanR).labels ' '] ];
    end

    %save in new folder
    OLDNAME = filesEEG(pp).name;
    NEWNAME.PRE = strrep(filesEEG(pp).name,'.cnt', '_PRE');
    EEG = pop_saveset(EEG, NEWNAME.PRE, DATASETS);
    EEG = eeg_checkset(EEG);

    [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG); %store the EEG dataset in ALLEEG variable (array of all datasets)
    end
end
%% ------------------------------------------


% Get list of files
filesEEGPRE = dir(DATASETS);

%amount of files in folder
nFilesPRE = length(filesEEGPRE);
filesEEGPRE = filesEEGPRE(3:nFilesPRE);
nFilesPRE = length(filesEEGPRE);

% ICA
 % change number according to dataset to be processed (even numbers, .set)
for pp = 2
    try
    ero = 'load error';   %set as different things throughout so we can see where the script stopped at for that pps to figure out what's going wrong      
    %loads sets that are .set files and from appropriate session
    if contains(filesEEGPRE(pp).name, SET) & contains(filesEEGPRE(pp).name, SESSION)
        EEG = pop_loadset(sprintf(strcat(DATASETS,'/%s'),  filesEEGPRE(pp).name)); %only even numbers, because of fdt and set files
    end
    
    EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on');
    EEG = eeg_checkset(EEG);
    pop_eegplot(EEG, 1, 0, 1);
    pop_selectcomps(EEG, [1:20]);
    EEG = eeg_checkset(EEG);

    load handel
    sound(y,Fs)
    
    % manually choose artifact components here in pop-up window
    
    %save in new folder
    OLDNAME.PRE = filesEEGPRE(pp).name;
    NEWNAME.ICA = strrep(filesEEGPRE(pp).name,'PRE', 'ICA');
    EEG = pop_saveset(EEG, NEWNAME.ICA, ICADATASETS);
    EEG = eeg_checkset(EEG);
    catch
    end
end
%% ------------------------------------------


% Get list of files
filesEEGICA = dir(ICADATASETS);

%amount of files in folder
nFilesICA = length(filesEEGICA);
filesEEGICA = filesEEGICA(3:nFilesICA);
nFilesICA = length(filesEEGICA);


% ERP - epoch, binlister, ERPSets
for pp = 1:nFilesICA
    ero = 'load error';   %set as different things throughout so we can see where the script stopped at for that pps to figure out what's going wrong      
    %loads sets that are .set files and from appropriate session
    if contains(filesEEGICA(pp).name, SET) & contains(filesEEGICA(pp).name, SESSION)
        EEG = pop_loadset(sprintf(strcat(ICADATASETS,'/%s'),  filesEEGICA(pp).name));
    else
        continue
    end

    %epoch segmentation
    % event list for ERPlab
    EEG  = pop_creabasiceventlist(EEG , 'AlphanumericCleaning', 'on', 'BoundaryNumeric', { -99 }, 'BoundaryString', { 'boundary' } );
    EEG = eeg_checkset(EEG);

    %bins  
    EEG  = pop_binlister(EEG , 'BDF', BINDESC, 'IndexEL',  1, 'SendEL2', 'EEG', 'Voutput', 'EEG');
    EEG = eeg_checkset(EEG);

    % epoch
    EEG = pop_epochbin(EEG, [EPOCHBEF  EPOCHAFT],  'pre');
    EEG = eeg_checkset(EEG);

    %artifact detection, subjects with >25% of epochs rejected will be removed
    %get amount of epochs before rejection
    trialsBefore = length(EEG.epoch);

    %artifact rejection
    EEG  = pop_artmwppth( EEG , 'Channel',  1:length(EEG.chanlocs), 'Flag',  1, 'LowPass',  -1, 'Threshold',  100, 'Twindow', [ EPOCHBEF EPOCHAFT], 'Windowsize',  200, 'Windowstep',  100 ); % GUI: 21-Jun-2022 14:32:02
    EEG1 = eeg_checkset( EEG );
    %pop_eegplot( EEG, 1, 1, 1);

    % get amount of epochs after rejection
    trialsAfter = length(EEG1.epoch);

    %calculate percentage of epochs rejected
    epochreject = ((trialsBefore-trialsAfter)/trialsBefore)*100
   
    % remove participant if >25% of epochs rejected - CHECK NOTES
    
    %nested loop, divide into bin epochs early and late
    for i = {'B1(10)', 'B2(20)'}
    
        %get relevant epochs
        EEG2 = pop_selectevent(EEG1 ,'type',{i},'deleteevents','off','deleteepochs','on','invertepochs','off');
        lists = [[1:8], [length(EEG2.epoch)-7:length(EEG2.epoch)]];
    
        for k = [1 2]
            if k == 1
                j = lists(1:8);
            else
                j = lists(9:16);
            end
            
            %cut the trials for analysis
            EEG = pop_selectevent(EEG2 ,'epoch', j,'deleteevents','off','deleteepochs','on','invertepochs','off');
            
            %averaging the data - and get ERPsets
            ERP = pop_averager(EEG , 'Criterion', 'good', 'DQ_custom_wins', 0, 'DQ_flag', 1, 'DQ_preavg_txt', 0, 'ExcludeBoundary','on', 'SEM', 'on' );
            
            %filter ERP
            ERP = pop_filterp(ERP,  1:length(EEG.chanlocs) , 'Cutoff',  ERPLOW, 'Design', 'butter', 'Filter', 'lowpass', 'Order',  2);
              
            %save in new folder
            OLDNAME.ICA = filesEEGICA(pp).name;
            NEWNAME.ERP = strrep(filesEEGICA(pp).name,'ICA.set',sprintf('_%s_%d.erp', i{:}, j(1)));
            ERP = pop_savemyerp(ERP, 'erpname', NEWNAME.ERP, 'filename', NEWNAME.ERP, 'filepath', ERPDATASETS, 'Warning', 'on');         
            
        end
    end
end
%% ------------

filesEEGERP = dir(ERPDATASETS);

nFilesERP = length(filesEEGERP);
filesEEGERP = filesEEGERP(3:nFilesERP);
nFilesERP = length(filesEEGERP);

for pp = 1:nFilesERP
    ERP = pop_loaderp('filename',filesEEGERP(pp).name,'filepath',ERPDATASETS,'overwrite','off','Warning','on');

    %save ERP files as .txt files
    OLDNAME.ERP = filesEEGERP(pp).name;
    NEWNAME.FINAL = strrep(filesEEGERP(pp).name,'.erp','');
    ALLERP = pop_geterpvalues(ERP, [LAT1 LAT2], [1 2],  1:64 , 'Baseline', 'pre', 'FileFormat', 'wide', 'Filename',...
     sprintf('C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_FINAL/%s.xls', NEWNAME.FINAL), 'Fracreplace', 'NaN', 'InterpFactor',  1, 'Measure', 'peakampbl', 'Neighborhood',  3, 'PeakOnset',  1, 'Peakpolarity', 'positive', 'Peakreplace', 'absolute', 'Resolution',  3 );
end
%% -------------




%% Notes
notes = load('C:\Users\inesa\OneDrive\Desktop\EEG_DATA\PARAPET_process\Notes.m','Writable', true);
notes.notes(1,1) = cellstr('ppNum');
notes.notes(1,2) = cellstr('Channels Rejected');
notes.notes(1,3)= cellstr('Epoch removed'); 
notes.notes(1,4) = cellstr('Percent removed');

notes.notes(pp+1,1) = cellstr(filesEEG(pp).name(1:n));
notes.notes(pp+1,2) = cellstr(length(channelsAfterRemove));
notes.notes(pp+1,3) = num2cell(trialsBefore - trialsAfter);
notes.notes(pp+1,4) = num2cell(epochreject);

