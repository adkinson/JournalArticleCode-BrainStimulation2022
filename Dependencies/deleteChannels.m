function [data,montageInfo] = deleteChannels(data,montageInfo,varargin)

% Parse Function Inputs
p = inputParser;
defaultChannels = [];
checkChannels = @(x) iscell(x)||isnumeric(x)||ischar(x);
defaultType = 'MID';
validTypes = {'MID','EID'};
checkTypes = @(x) any(validatestring(x,validTypes));
addRequired(p,'data',@ismatrix)
addRequired(p,'montageInfo',@isstruct)
addOptional(p,'channels',defaultChannels,checkChannels)
addOptional(p,'type',defaultType,checkTypes)
parse(p,data,montageInfo,varargin{:})

remove = p.Results.channels;
rmvType = p.Results.type;

if isempty(remove)
    return
end

if size(montageInfo.Current,1)~=size(data)
    error('The number of channels found on the data''s channel dimension does not match the number of channels in MontageInfo.Current')
end

if isnumeric(remove)
    rIdx = remove;
    if strcmp(rmvType,'MID')
        [~,tmpIdx] = intersect(montageInfo.Current.MatrixID,rIdx);
    else
        [~,tmpIdx] = intersect(montageInfo.Current.ElectrodeID,rIdx,'stable');
    end
elseif iscell(remove)
    if any(strcmp(remove,'Empty')) && isfield(montageInfo,'Empty')
        eIdx = montageInfo.Empty.Indices;
    else
        eIdx = [];
    end
    if any(strcmp(remove,'Flagged')) && isfield(montageInfo,'FlaggedChannels')
        flgIdx = montageInfo.FlaggedChannels.ElectrodeID;
    else
        flgIdx = [];
    end
    lID = cellfun(@ischar,remove);
    [~,tmpA] = intersect(montageInfo.Current.Label,remove(lID),'stable');
    [~,tmpB] = intersect(montageInfo.Current.ElectrodeID,[eIdx(:);flgIdx(:)]);
    if any(cellfun(@isnumeric,remove))
        idx = cellfun(@isnumeric,remove);
        rIdx = [remove{idx}];
        if strcmp(rmvType,'MID')
            [~,tmpC] = intersect(montageInfo.Current.MatrixID,rIdx);
        else
            [~,tmpC] = intersect(montageInfo.Current.ElectrodeID,rIdx,'stable');
        end
    else
        tmpC = [];
    end
    tmpIdx = unique([tmpA; tmpB; tmpC],'stable');
elseif ischar(remove)
    if strcmp(remove,'Empty') && isfield(montageInfo,'Empty')
        eIdx = montageInfo.Empty.Indices;
        [~,tmpIdx] = intersect(montageInfo.Current.ElectrodeID,eIdx);
    elseif strcmp(remove,'Flagged') && isfield(montageInfo,'FlaggedChannels')
        flgIdx = montageInfo.FlaggedChannels.ElectrodeID;
        [~,tmpIdx] = intersect(montageInfo.Current.ElectrodeID,flgIdx);
    else
        [~,tmpIdx] = intersect(montageInfo.Current.Label,remove,'stable');
    end
end

rmvIdx = montageInfo.Current.MatrixID(tmpIdx);
keepIdx = setdiff(montageInfo.Current.MatrixID,rmvIdx);

montageInfo.Current(rmvIdx,:) = [];
montageInfo.Current.MatrixID = (1:size(montageInfo.Current,1))';

if exist('flgIdx','var') && ~isempty(flgIdx)
    montageInfo = rmfield(montageInfo,'FlaggedChannels');
end

dimIndices = cellstr(':');
dimIndices = repmat(dimIndices,[ndims(data) 1]);
dimIndices{montageInfo.ChannelDim} = keepIdx;

data = data(dimIndices{:});

end