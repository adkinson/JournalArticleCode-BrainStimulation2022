%% Get Files
fileExt = 'ns5';
location = 'DataServer';

pathRoot = environmentPath(location);
dirData = uigetfilesfolders(pathRoot,'DIRECTORIES_ONLY','Select Data');
if isempty(dirData)
    return
end
subjectID = regexp(dirData(1).folder,'([a-zA-Z0-9]+)Datafile','tokens');
% subject = regexp(files{1},'subj?-([a-zA-Z0-9]+)','tokens'); %<-Could
% include in for loop as a check that the right data is in the folder
subjectID = vertcat(subjectID{:});
subjectID = vertcat(subjectID{:});

files = cell(length(dirData),1);
for i = 1:length(dirData)
    tmp = dir(fullfile(dirData(i).folder,dirData(i).name));
    files{i} = tmp([tmp.isdir]==0);
end
files = cat(1,files{:});

% File Check
idx1 = contains({files.name},['.',fileExt]);
idx2 = contains({files.name},'_NSP-1');
if any(idx2)
    idx = idx1 & idx2;
else
    idx = idx1;
end
if ~any(idx)
    error('Files containing the requested info not detected.')
end
selectedFiles = files(idx);

% Get Channel Data File
pathMeta = environmentPath('Meta',subjectID);
dirMeta = uigetfilesfolders(pathMeta,'FILES_ONLY','Select Electrodes CSV');
if ~isempty(dirMeta)
    MetaTable = readtable(fullfile(dirMeta.folder,dirMeta.name));
else
    MetaTable = [];
end

%%
for f = 1:length(selectedFiles)
    fprintf('File %d of %d: %s\n',f,length(selectedFiles),selectedFiles(f).name)    
    [filePath,fileName,fileExt] = fileparts(fullfile(selectedFiles(f).folder,selectedFiles(f).name));
    p = parseBIDSfilename(fileName);

    %% Setup variables from filename
    % Saving Directory
    pathEpoch = environmentPath('EpochedData',p.subj,p.task);
    if ~exist(pathEpoch,'dir')
        mkdir(pathEpoch)
    end

    % Set Default Timing Window
    pathTime = environmentPath('Timing',p.subj,p.task);
    secPreEvent = 0.25;                       %Observation Window Shift from Stimulus in Seconds
    secPostEvent = 0.5;
    timeWindow = secPreEvent+secPostEvent;        %Observation Window Width in Seconds

    switch p.task
        case 'PEP-ImageBased'
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.lead,'_',p.run,'_',p.elec,'.mat']));
            saveFilename = [p.task,'_',p.lead,'_',p.run,'_',p.elec,'.mat'];
        case 'ClinicalSPES'
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.lead,'_',p.elec,'_',p.current,'.mat']));
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'_',p.current,'.mat'];
        case 'ClinicalStim'
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.lead,'_',p.elec,'_',p.freq,'_',p.current,'.mat']));
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'_',p.freq,'_',p.current,'.mat'];
        case {'PEP-Multi','PEP-Multi2'}
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.source,'_',p.leads,'.mat']));
            saveFilename = [p.task,'_',p.source,'_',p.leads,'.mat'];
        case 'PEP-Additivity'
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.elec,'.mat']));
            saveFilename = [p.task,'_',p.elec,'.mat'];
        case 'PEP-Illumina'
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.lead,'.mat']));
            saveFilename = [p.task,'_',p.lead,'.mat'];
        case {'FreqPEP','FreqPEP-Combo'}
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.lead,'_',p.elec,'_',p.freq,'.mat']));
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'_',p.freq,'.mat'];
            secPreEvent = 0;
            secPostEvent = 1.25;
            timeWindow = secPreEvent+secPostEvent;
        otherwise
            eventMarkers = load(fullfile(pathTime,[p.task,'_',p.lead,'_',p.elec,'.mat']));
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'.mat'];
    end


    %% Load Signal Data
    NSx = openNSx([fullfile(filePath,fileName),fileExt],'p:double');
    NSx = processNSx(NSx);
    
    MontageInfo = parseNSxElectrodesInfo(NSx,'MetaTable',MetaTable);
    Signal = NSx.Data;
    
    tmp = find(MontageInfo.Current.Type=='Analog');
    if ~isempty(tmp)
        [Signal,MontageInfo] = deleteChannels(Signal,MontageInfo,tmp);
    end
    
    [~,channelInd] = sortrows(MontageInfo.Current,{'Lead','ElectrodeID'});
    [Signal,MontageInfo] = selectChannels(Signal,MontageInfo,channelInd);
    
    
    %% Filter Data %%
%     % 50Hz Lowpass
%     N=512;
%     freqConv = 2/NSx.MetaTags.SamplingFreq;
%     lp = 50;
%     f0 = lp*freqConv;
%     lp = fir1(N,f0,window(@hamming,N+1));
%     FiltSignal = filtfilt(lp,1,RawSignal')';
%     
%     % Bandpass Subtraction
%     N = 512;
%     freqConv = 2/NSx.MetaTags.SamplingFreq;
%     bp = {[55 65],[115 125],[175 185]};
%     f0 = cellfun(@(x) x*freqConv,bp,'Uni',0);
%     [b,a] = cellfun(@(x) fir1(N,x,'stop',window(@hamming,N+1)),f0,'Uni',0);
%     b1 = b{1};
%     for i = 2:length(b)
%         b1 = conv(b1,b{i});
%     end
%     tmp = zeros(1,length(b1));
%     tmp(ceil(length(b1)/2)) = 1;
%     filterFin = tmp-b1;
%     NotchedSignal = filtfilt(filterFin,1,RawSignal')';
    
    
    %% Rereference Data %%
    Signal = rereference(Signal,'None');

    
    %% Remap Timing Vector to Match Sampling Frequency of Data
    timingIdx = eventMarkers.TimingVector;
    timingSF = eventMarkers.SamplingFreq;
    dataSF = NSx.MetaTags.SamplingFreq;
    if dataSF~=timingSF
        factorSF = dataSF/timingSF;
        timingIdx = round(timingIdx*factorSF);
    end

    
    %% Remove Stimulation Artifact (Replace with 0's)
    if strcmp(p.task,'ClinicalStim')
        secPreStim = 0.0005;
        secPostStim = 0.004;
        for i=1:length(timingIdx)
            t = timingIdx(i)-round(secPreStim*dataSF)+1:timingIdx(i)+round((secPostStim)*dataSF);
            Signal(:,t(t>0)) = 0;
        end
    end
    
    
    %% Epoching %%
    % Line Up Data with Respect to Stimulation Pulse
    data = zeros(size(Signal,1),timeWindow*dataSF,length(timingIdx));
    deleteTrialsBool = false(length(timingIdx),1);
    for i=1:length(timingIdx)
        t = timingIdx(i)-round(secPreEvent*dataSF)+1:timingIdx(i)+round(secPostEvent*dataSF);
        if any(t<0)
            deleteTrialsBool(i) = true;
            continue
        elseif any(t>size(Signal,2))
            deleteTrialsBool(i) = true;
        else
            data(:,:,i) = Signal(:,t);
        end
    end
    if ~isempty(deleteTrialsBool)
        data(:,:,deleteTrialsBool) = [];
    end
    
    
    %% Decimate Epoched Data
    currentSF  = NSx.MetaTags.SamplingFreq;
    targetSF = 2000;
    factor = currentSF/targetSF;
    if factor~=1
        data1 = zeros(size(Signal,1),ceil(timeWindow*dataSF/factor),length(timingIdx));
        for i = 1:size(data,1)
            for j = 1:size(data,3)
                data1(i,:,j) = decimate(data(i,:,j),factor);
            end
        end
        PEP.Data = data1;
    else
        PEP.Data = data;
    end
    
    xAxis = linspace(((-1*secPreEvent*dataSF)+1)/dataSF,secPostEvent,timeWindow*dataSF)*1000; % In milliseconds
    PEP.xAxis = xAxis(factor:factor:end);
    PEP.MontageInfo = MontageInfo;
    

    %% Save Epoched Data    
    save(fullfile(pathEpoch,saveFilename),'-struct','PEP')
end
beep