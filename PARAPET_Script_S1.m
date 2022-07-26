%DELETE .EVT FILES FROM PARAPET FOLDER
%define variables
FOLDER = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_S1';
DATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_DATASETS';
ICADATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_ICA';
ERPDATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_ERP';
FINALDATASETS = 'C:/Users/inesa/OneDrive/Desktop/EEG_DATA/PARAPET_1/PARAPET_FINAL';
CNT = 'cnt';
SET = 'set';
ERP = 'erp';
SESSION = 'S1'; %change according to script
LOWCUT = 0.5;
HIGHCUT = 50;
SAMPLER = 512;
EPOCHBEF = -200.0;
EPOCHAFT = 1000.0; %maybe 2000 if needed
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
for pp = 14
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
            
            % bin operations
%             ERP = pop_binoperator(ERP, {ERPBIN});
%             ERP = pop_erpchanoperator( ERP, {  'nch1 = ch1 - ( avgchan(1:64) ) Label Fp1',  'nch2 = ch2 - ( avgchan(1:64) ) Label Fpz',...
%               'nch3 = ch3 - ( avgchan(1:64) ) Label Fp2',  'nch4 = ch4 - ( avgchan(1:64) ) Label F7',  'nch5 = ch5 - ( avgchan(1:64) ) Label F3',  'nch6 = ch6 - ( avgchan(1:64) ) Label Fz',...
%               'nch7 = ch7 - ( avgchan(1:64) ) Label F4',  'nch8 = ch8 - ( avgchan(1:64) ) Label F8',  'nch9 = ch9 - ( avgchan(1:64) ) Label FC5',...
%               'nch10 = ch10 - ( avgchan(1:64) ) Label FC1',  'nch11 = ch11 - ( avgchan(1:64) ) Label FC2',  'nch12 = ch12 - ( avgchan(1:64) ) Label FC6',...
%               'nch13 = ch13 - ( avgchan(1:64) ) Label M1',  'nch14 = ch14 - ( avgchan(1:64) ) Label T7',  'nch15 = ch15 - ( avgchan(1:64) ) Label C3',...
%               'nch16 = ch16 - ( avgchan(1:64) ) Label Cz',  'nch17 = ch17 - ( avgchan(1:64) ) Label C4',  'nch18 = ch18 - ( avgchan(1:64) ) Label T8',...
%               'nch19 = ch19 - ( avgchan(1:64) ) Label M2',  'nch20 = ch20 - ( avgchan(1:64) ) Label CP5',  'nch21 = ch21 - ( avgchan(1:64) ) Label CP1',...
%               'nch22 = ch22 - ( avgchan(1:64) ) Label CP2',  'nch23 = ch23 - ( avgchan(1:64) ) Label CP6',  'nch24 = ch24 - ( avgchan(1:64) ) Label P7',...
%               'nch25 = ch25 - ( avgchan(1:64) ) Label P3',  'nch26 = ch26 - ( avgchan(1:64) ) Label Pz',  'nch27 = ch27 - ( avgchan(1:64) ) Label P4',...
%               'nch28 = ch28 - ( avgchan(1:64) ) Label P8',  'nch29 = ch29 - ( avgchan(1:64) ) Label POz',  'nch30 = ch30 - ( avgchan(1:64) ) Label O1',...
%               'nch31 = ch31 - ( avgchan(1:64) ) Label O2',  'nch32 = ch32 - ( avgchan(1:64) ) Label EOG',  'nch33 = ch33 - ( avgchan(1:64) ) Label AF7',...
%               'nch34 = ch34 - ( avgchan(1:64) ) Label AF3',  'nch35 = ch35 - ( avgchan(1:64) ) Label AF4',  'nch36 = ch36 - ( avgchan(1:64) ) Label AF8',...
%               'nch37 = ch37 - ( avgchan(1:64) ) Label F5',  'nch38 = ch38 - ( avgchan(1:64) ) Label F1',  'nch39 = ch39 - ( avgchan(1:64) ) Label F2',...
%               'nch40 = ch40 - ( avgchan(1:64) ) Label F6',  'nch41 = ch41 - ( avgchan(1:64) ) Label FC3',  'nch42 = ch42 - ( avgchan(1:64) ) Label FCz',...
%               'nch43 = ch43 - ( avgchan(1:64) ) Label FC4',  'nch44 = ch44 - ( avgchan(1:64) ) Label C5',  'nch45 = ch45 - ( avgchan(1:64) ) Label C1',...
%               'nch46 = ch46 - ( avgchan(1:64) ) Label C2',  'nch47 = ch47 - ( avgchan(1:64) ) Label C6',  'nch48 = ch48 - ( avgchan(1:64) ) Label CP3',...
%               'nch49 = ch49 - ( avgchan(1:64) ) Label CP4',  'nch50 = ch50 - ( avgchan(1:64) ) Label P5',  'nch51 = ch51 - ( avgchan(1:64) ) Label P1',...
%               'nch52 = ch52 - ( avgchan(1:64) ) Label P2',  'nch53 = ch53 - ( avgchan(1:64) ) Label P6',  'nch54 = ch54 - ( avgchan(1:64) ) Label PO5',...
%               'nch55 = ch55 - ( avgchan(1:64) ) Label PO3',  'nch56 = ch56 - ( avgchan(1:64) ) Label PO4',  'nch57 = ch57 - ( avgchan(1:64) ) Label PO6',...
%               'nch58 = ch58 - ( avgchan(1:64) ) Label FT7',  'nch59 = ch59 - ( avgchan(1:64) ) Label FT8',  'nch60 = ch60 - ( avgchan(1:64) ) Label TP7',...
%               'nch61 = ch61 - ( avgchan(1:64) ) Label TP8',  'nch62 = ch62 - ( avgchan(1:64) ) Label PO7',  'nch63 = ch63 - ( avgchan(1:64) ) Label PO8',...
%               'nch64 = ch64 - ( avgchan(1:64) ) Label Oz'} , 'ErrorMsg', 'popup', 'KeepLocations',  1, 'Warning', 'on' );
           

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
notes.notes(1,5) = cellstr('Amount of event markers');

notes.notes(pp+1,1) = cellstr(filesEEG(pp).name(1:n));
notes.notes(pp+1,2) = cellstr(length(channelsAfterRemove));
notes.notes(pp+1,3) = num2cell(trialsBefore - trialsAfter);
notes.notes(pp+1,4) = num2cell(epochreject);
notes.notes(pp+1,5) = num2cell(length(eventIndexes));

