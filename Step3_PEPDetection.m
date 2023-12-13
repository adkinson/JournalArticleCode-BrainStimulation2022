%% Get Files
location = 'Analysis';
pathRoot = environmentPath(location);
dirData = uigetfilesfolders(pathRoot,'FILES_ONLY','Select EpochedData Files to Analyze');
if isempty(dirData)
    return
end

dirSave = uigetfilesfolders(pathRoot,'DIRECTORIES_ONLY','Select Folder to Save Results');

idx = contains({dirData.name},'.mat');
dirData = dirData(idx);

%%
for f = 1:length(dirData)
    %% Load Data %%
    fprintf('Analyzing %d of %d: %s\n',f,length(dirData),dirData(f).name)
    load(fullfile(dirData(f).folder,dirData(f).name),'MontageInfo','xAxis','Data');
    sEEGIdx = find(MontageInfo.Current.Type=='sEEG');
    ContactsAnalyzed = MontageInfo.Current.Label(sEEGIdx);
    Data = Data(sEEGIdx,:,:);
    MontageLeads = MontageInfo.Current.Lead(sEEGIdx);
    MontageLeadNames = unique(MontageLeads);
    MontageLeadIndices = cell(size(MontageLeadNames));
    for i = 1:length(MontageLeadIndices)
        MontageLeadIndices{i} = find(MontageLeads==MontageLeadNames(i));
    end
    
    
    %% Rereference Data %%
    RerefMethod = 'None';
    RerefData = zeros(size(Data));    
    for i = 1:size(Data,3)
        RerefData(:,:,i) = rereference(Data(:,:,i),RerefMethod,MontageLeadIndices);
    end
    
    
    %% Analysis for Each SFM (Determining which SFM/sEEGs have Responses)
    % Initial Parameters
    analysisWindow = (xAxis>=10 & xAxis<=200);
    PEPDetection = false(size(Data,1),1);
    
    
    %% Comparison to Shuffled Trials (Observed Window) w/ Monte Carlo
    PEPWindow = RerefData(:,analysisWindow,:);
    iter = 1000;
    chk = zeros(size(PEPWindow,1),iter);
    stdShuffles = zeros(size(PEPWindow,1),iter);
    PEPmean = mean(PEPWindow,3);
    PEPstd = std(PEPmean,[],2);
    
    ShufflePEP = zeros(size(PEPWindow));
    for h = 1:iter
        % Shuffle Trials
        for j = 1:size(PEPWindow,3)
            ShufflePEP(:,:,j) = PEPWindow(:,randperm(size(PEPWindow,2)),j);
        end
        
        % Calculate Std of Averaged Shuffled Trials
        meanShufflePEP = mean(ShufflePEP,3);
        stdShufflePEP = std(meanShufflePEP,[],2);
        
        % Threshold
        stdShuffles(:,h) = stdShufflePEP;
    end
    chk = PEPstd./stdShuffles>3;
    PEPDetection(sEEGIdx) = sum(chk,2)>0.95*iter;
    PEPResponse = table(ContactsAnalyzed,PEPDetection(sEEGIdx),'VariableNames',{'Contacts','PEP_Detected'});
    save(fullfile(dirSave.folder,dirSave.name,['Threshold_',dirData(f).name]),'PEPResponse')

end
beep