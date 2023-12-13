function [data,montageInfo] = selectChannels(data,montageInfo,varargin)
% Parse Inputs
p = inputParser;
defaultChannels = [];
checkChannels = @(x) iscell(x)||isnumeric(x);
defaultType = 'MID';
validTypes = {'MID','EID'};
checkTypes = @(x) any(validatestring(x,validTypes));
addRequired(p,'data',@ismatrix)
addRequired(p,'montageInfo',@isstruct)
addOptional(p,'channels',defaultChannels,checkChannels)
addOptional(p,'type',defaultType,checkTypes)
parse(p,data,montageInfo,varargin{:})

reorder = p.Results.channels;
type = p.Results.type;

if isempty(reorder)
    return
end

if size(montageInfo.Current,1)~=size(data)
    error('The number of channels found on the data''s channel dimension does not match the number of channels in MontageInfo.Current')
end

% Modify Current MontageInfo Table
if isnumeric(reorder)
    if strcmp(type,'MID')
        [~,~,reorderIdx] = intersect(reorder,montageInfo.Current.MatrixID,'stable');
    else
        [~,~,reorderIdx] = intersect(reorder,montageInfo.Current.ElectrodeID,'stable');
    end
elseif iscell(reorder)
    [~,~,reorderIdx] = intersect(reorder,montageInfo.Current.Label,'stable');
end

T = montageInfo.Current(reorderIdx,:);
T.MatrixID = (1:size(T,1))';

montageInfo.Current = T;

% Permute Data
dimIndices = arrayfun(@(x) 1:x,size(data),'Uni',0);
dimIndices{montageInfo.ChannelDim} = reorderIdx;

data = data(dimIndices{:});


end