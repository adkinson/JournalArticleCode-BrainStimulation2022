function channelInfo = parseNSxElectrodesInfo(varargin)
%PARSENSXELECTRODESINFO Parses Electrode information from Blackrock Neural
%Signal Files.
% 
% CODE PURPOSE
% (1) To tie the matrix of channel data to a header informing the user of
% the content of each channel.
% (2) To provide a means of maintaining data/header integrity through
% transformations of the data.
% (3) To create a means of efficiently encoding header information for
% efficient use in figures and applications.
% 
% SYNTAX
% montageInfo = parseNSxElectrodesInfo()
% montageInfo = parseNSxElectrodesInfo(S)
% montageInfo = parseNSxElectrodesInfo(__,Name,Value)
% 
% DESCRIPTION
% parseNSxElectrodesInfo() is designed to read label information from NSx
% files and parse that information into subfields associated with commonly
% recognized neural signal types (sEEG,Grid,Microwires,etc.) as utilized in
% the Baylor College of Medicine Epilepsy Monitoring Unit (EMU) Research Lab.
% 
% INPUTS
% If no inputs are provided, a prompt will request the desired .NSx
% Blackrock file
% S can either be a previously loaded NSx structure or a filename/path to
% the desired Blackrock file.
% 
% NAME/VALUE PAIRS
% 'FlagChannels' - Flags channels for later deletion
%   Input can be (1) a cell of channel names matching the list of names in
%   NSx.ElectrodesInfo.Labels or (2) a numerical vector listing the
%   NSx.ElectrodesInfo.ElectrodeID values to be flagged.
%   NOTE: Flagged Channels are included in a separate table called
%       'FlaggedChannels' in the channelInfo structrue.
% 'MetaTable' - Include imaging metadata of electrodes into parsing process
%   Input should be the specially made in-house table XXXelectrodes.csv
%   which contains scrubbed versions of the NSx.ElectrodesInfo.Labels as
%   well as many types of useful imaging information about each electrode
%   that was implanted into patient XXX during their stay in the EMU. As
%   more types of imaging information are added to the file, those inputs
%   will be considered for additions into this parsing function.
% 
% OUTPUT
% channelInfo - a struct parsing the electrode IDs, their respective
% labels, and their position (row/column) in the data. The channelInfo
% structure will always contain some fields, including (1) Original (the
% raw version of NSx.ElectrodesInfo) and (2) Current (a direct reflection
% of the channels in the associated data). Many other structures can occur
% depending on the how channels are labeled in NSx.ElectrodesInfo.
% 
% Author: Joshua A. Adkinson

% Parse Function Inputs
p = inputParser;
defaultVariable = [];
checkVariable = @(x) isstruct(x)||ischar(x);
defaultRemove = {};
defaultTable = table;
addOptional(p,'variable',defaultVariable,checkVariable)
addParameter(p,'FlagChannels',defaultRemove)
addParameter(p,'MetaTable',defaultTable)
parse(p,varargin{:})
variable = p.Results.variable;
flagChannels = p.Results.FlagChannels;
metaTable = p.Results.MetaTable;

% Collect NSx data structure
if isempty(variable)
    [filename,path] = uigetfile('*.*');
    [path,filename,fileExt] = fileparts(fullfile(path,filename));
    if isempty(regexp(fileExt,'.ns\d','once'))
        error('Selected file must be one of the .NSx Blackrock file extensions.')
    end
    dataStruct = openNSx(fullfile(path,[filename,fileExt]),'noread');
    dataStruct = dataStruct.ElectrodesInfo;
else
    if isstruct(variable)
        dataStruct = variable;
        dataStruct = dataStruct.ElectrodesInfo;
    elseif ischar(variable)
        [path,filename,fileExt] = fileparts(variable);
        if isempty(regexp(fileExt,'.ns\d','once'))
            error('Input file must be one of the .NSx Blackrock file extensions.')
        end
        dataStruct = openNSx(fullfile(path,[filename,fileExt]),'noread');
        dataStruct = dataStruct.ElectrodesInfo;
    else
        error('Invalid function input. This function allows the path/filename of the desired Blackrock file or the struct created after using the OpenNSx function.')
    end
end

% Collect Labels,IDs, and Denote Analog Inputs if any
ElectrodeLabels = {dataStruct.Label}';
ElectrodeID = [dataStruct.ElectrodeID]';

if any([dataStruct.MaxAnalogValue]==5000)
    ainpMindices = find([dataStruct.MaxAnalogValue]==5000);
    ainpEindices = ElectrodeID(ainpMindices);
    ainpLabels = ElectrodeLabels(ainpMindices);
end

% % Detect Analog Input from Electrode List if not done already
% if ~exist('ainpMindices','var')
%     ainpLabelTemplate = '(Photodiode|Audio|Mic|StimSync1|StimSync2|Cerestim|FaceCam|BodyCam|RecordingSync|Strobe|RPupil)';
%     ainpLabels = regexp(ElectrodeLabels,ainpLabelTemplate,'match');
%     ainpMindices = find(cellfun(@isempty,ainpLabels)==0);
%     ainpEindices = ElectrodeID(ainpMindices);
%     ainpLabels = vertcat(ainpLabels{:});
% end

% Process Name/Value Pair Arguments
% MetaTable
if ~isempty(metaTable)
    metaTableFields = fieldnames(metaTable);
    idx = contains(metaTableFields,'ROI_vis');
    metaTableEID = metaTable.ElectrodeID;
%     [~,indEIDtoMeta,indMeta] = intersect(ElectrodeID,metaTableEID,'stable');
end
% FlagChannels
if ~isempty(flagChannels)
    if iscell(flagChannels)
        [~,iA] = intersect(deblank(ElectrodeLabels),flagChannels,'stable');
        if length(iA)~=length(flagChannels)
            warning('One or more names in the ''RemoveElectrodes'' list does not match the Electrode Labels in the NSx file')
        end
        flagChannels = ElectrodeID(iA);
    end
    if ~isempty(metaTable)
        ROIs = categorical(metaTable.(metaTableFields{idx}));
        idx = (ROIs=='NA'|ROIs=='Bolt');
        badImagingChannels = metaTableEID(idx);
        badImagingChannels = intersect(ElectrodeID,badImagingChannels);
        badSignalChannels = flagChannels;
        flagChannels = union(badImagingChannels,badSignalChannels);
        [~,rmv] = intersect(ElectrodeID,flagChannels);
    else
        [~,rmv] = intersect(ElectrodeID,flagChannels);
    end
else
    rmv = [];
end

% Initialize ChannelInfo Structure
channelInfo = struct();

% Scrub ElectrodeLabels
suffixTemplate = '-[0-9]{3}$';
ElectrodeLabels = deblank(ElectrodeLabels);
ElectrodeLabels = regexprep(ElectrodeLabels,suffixTemplate,'');

% Write Current Structure
channelInfo.Current.Label = ElectrodeLabels;
channelInfo.Current.MatrixID = (1:length(ElectrodeID))';
channelInfo.Current.ElectrodeID = ElectrodeID;

% Add Recording Type
tmp = cellstr(repmat('NA',length(ElectrodeLabels),1));
indM = ~cellfun(@isempty,regexp(ElectrodeLabels,'^m','once'));
tmp(indM) = cellstr('Micro');
indD = ~cellfun(@isempty,regexp(ElectrodeLabels,'^d','once'));
tmp(indD) = cellstr('DBS');
indE = ~cellfun(@isempty,regexp(ElectrodeLabels,'^x','once'));
tmp(indE) = cellstr('External');
indG = ~cellfun(@isempty,regexp(ElectrodeLabels,'^g','once'));
tmp(indG) = cellstr('Grid');
indS = ~cellfun(@isempty,regexp(ElectrodeLabels,'^[Ll|Rr]','once'));
tmp(indS) = cellstr('sEEG');
indC = ~cellfun(@isempty,regexp(ElectrodeLabels,'^C','once'));
tmp(indC) = cellstr('REF');
indZ = ~cellfun(@isempty,regexp(ElectrodeLabels,'^Z','once'));
tmp(indZ) = cellstr('GND');
tmp(ainpMindices) = cellstr('Analog');
channelInfo.Current.Type = categorical(tmp);

% Add Lead Label
tmp = ElectrodeLabels;
tmp(indD|indE|indG|indC|indZ) = cellfun(@(x) x(2:end),ElectrodeLabels(indD|indE|indG|indC|indZ),'Uni',0);
tmp = regexprep(tmp,'-*[0-9]{2,3}$','');
tmp(ainpMindices) = cellstr('Analog');
channelInfo.Current.Lead = categorical(tmp);
channelInfo.Current.Lead = addcats(channelInfo.Current.Lead,'NA');
channelInfo.Current.Lead(channelInfo.Current.Type=='NA') = 'NA';

% Convert to Table
channelInfo.Current = struct2table(channelInfo.Current);

% Add MetaTable Info
if ~isempty(metaTable)
    metaTableLabels = metaTable.Label;
    [~,newColumnsInd] = setdiff(metaTable.Properties.VariableNames,channelInfo.Current.Properties.VariableNames,'stable');
    varTypes = varfun(@class,metaTable,'OutputFormat','cell');
    tmp = table('Size',[size(channelInfo.Current,1),length(newColumnsInd)],'VariableTypes',varTypes(newColumnsInd),'VariableNames',metaTable.Properties.VariableNames(newColumnsInd));
    [~,indNSxtoMeta,indMeta] = intersect(ElectrodeLabels,metaTableLabels,'stable');
    tmp(indNSxtoMeta,:) = metaTable(indMeta,newColumnsInd);
    cellVar = find(varfun(@iscell,tmp,'OutputFormat','uniform')==1);
    outsideBrainIndices = find(cellfun(@isempty,tmp{:,cellVar(1)}));
    tmp{outsideBrainIndices,cellVar} = repmat(cellstr('NA'),[length(outsideBrainIndices),length(cellVar)]);
    for i = 1:length(cellVar)
        tmp.(cellVar(i)) = categorical(tmp.(cellVar(i)));
    end
    channelInfo.Current = [channelInfo.Current tmp];
end 

% Store Table Copy
channelInfo.Original = channelInfo.Current;

% Reference/Ground
rgIdx = find(indC|indZ);
rgIdx = setdiff(rgIdx,ainpMindices);

% Flagging Channels
if ~isempty([rgIdx(:); rmv(:)])
    rmvMidx = union(rgIdx(:),rmv(:));
    rmvEidx = ElectrodeID(rmvMidx(:));
    channelInfo.FlaggedChannels.Labels = ElectrodeLabels(rmvMidx(:));
    channelInfo.FlaggedChannels.MatrixID = rmvMidx(:);
    channelInfo.FlaggedChannels.ElectrodeID = rmvEidx(:);
    channelInfo.FlaggedChannels = struct2table(channelInfo.FlaggedChannels);
end

if ~isempty(ainpMindices)
    channelInfo.AnalogInput = table(ainpLabels,ainpMindices(:),ainpEindices(:),'VariableNames',{'Labels','Indices','EID'});
end

channelInfo.ChannelDim = 1;
montageFields = fieldnames(channelInfo);

% Sort MontageInfo Fieldnames
namesSubset = intersect({'Current','sEEG','Grid','micro','DBS','ECG','External','AnalogInput','FlaggedChannels','NonEmpty','Empty','Original','ChannelDim'},montageFields,'stable');
channelInfo = orderfields(channelInfo,namesSubset);
end