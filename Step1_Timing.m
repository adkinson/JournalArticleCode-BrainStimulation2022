%% Get Files
fileExt = 'ns5';
location = 'DataServer';
threshold = 2000;
outputSR = 30000;

pathRoot = environmentPath(location);
dirData = uigetfilesfolders(pathRoot,'DIRECTORIES_ONLY','Select Data Folders');
if isempty(dirData)
    return
end

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

%%
for f = 1:length(selectedFiles)
    fprintf('File %d of %d: %s\n',f,length(selectedFiles),selectedFiles(f).name)    
    [filePath,fileName,fileExt] = fileparts(fullfile(selectedFiles(f).folder,selectedFiles(f).name));
    p = parseBIDSfilename(fileName);

    %% Setup variables from filename
    % Saving Directory
    pathTime = environmentPath('Timing',p.subj,p.task);
    if ~exist(pathTime,'dir')
        mkdir(pathTime)
    end
    
    % Saving Filename
    switch p.task
        case 'PEP-ImageBased'
            saveFilename = [p.task,'_',p.lead,'_',p.run,'_',p.elec,'.mat'];
        case 'PEP-Illumina'
            saveFilename = [p.task,'_',p.lead,'.mat'];
        case 'ClinicalSPES'
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'_',p.current,'.mat'];
        case 'ClinicalStim'
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'_',p.freq,'_',p.current,'.mat'];
        case {'PEP-Multi','PEP-Multi2'}
            saveFilename = [p.task,'_',p.source,'_',p.leads,'.mat'];
        case 'PEP-Additivity'
            saveFilename = [p.task,'_',p.elec,'.mat'];
        case {'PEP-Combo','PEP-Combo2'}
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'.mat'];
        case {'FreqPEP','FreqPEP-Combo'}
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'_',p.freq,'.mat'];
        otherwise
            saveFilename = [p.task,'_',p.lead,'_',p.elec,'.mat'];
    end

    %% Load Data %%
    NSx = openNSx([fullfile(filePath,fileName),fileExt],'noread');
    tmp = {NSx.ElectrodesInfo.Label}';
    stimSyncID = find(~cellfun(@isempty,regexp(tmp,'StimSync'))==1);
    NSx = openNSx([fullfile(filePath,fileName),fileExt],['c:',int2str(stimSyncID)]);
    NSx = processNSx(NSx);
    NSx.Data = NSx.Data(1,:);
    
    inputSR = NSx.MetaTags.SamplingFreq;
    
    % Calculate TimingMarkers
    stimSyncData = NSx.Data;
    timingVector = find(stimSyncData>threshold);
    tmp = find(diff(timingVector)>1);
    timingVector = timingVector([1 tmp+1]);
    
    % Create Structure
    Epoch.TimingVector = round(timingVector/(inputSR/outputSR));
    Epoch.SamplingFreq = outputSR;

    % Save Data
    fprintf('Saving: %s\n',saveFilename);
    fprintf('Number of Markers: %d\n\n',length(timingVector))
    save(fullfile(pathTime,saveFilename),'-struct','Epoch')
end
beep