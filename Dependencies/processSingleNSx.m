function NSx = processSingleNSx(NSx)
%PROCESSSINGLENSX Handles Blackrock NSx data/timing issues related to packet loss.
%
% CODE PURPOSE
% Stitch together multiple data cells into a single matrix in a manner
% specified by the user.
%
% SYNTAX
% NSx = processSingleNSx(NSx)
%
% DESCRIPTION
% processSingleNSx() is designed concatenate data caused by packet loss or
% pause events that occured during acquisition of the given Blackrock NSx
% data structure by utilizing the 'Timestamp' values provided within the
% structure. Packetloss/pause events cause a temporal gap within the
% datastream. Separate datastreams will be concatenated via a few possible
% options that can be chosen by the user. The user can choose (1) no
% padding, (2) zero padding, or (3) NaN padding.
%
% NOTES
% (1) To allow for batch handling of multiple NSx filesets, the choices
% made by the user will persist until a call to 'clear processNSx'.
% (2) In the event the timestamp is recognized as a Blackrock
% synchronization of multiple NSPs, all cells prior to the synchronization
% event will be ignored/deleted.
% (3) This function is used within the processNSx() function when
% synchronization of two NSP datasets cannot be accomplished by
% processNSx(). This function does not perform the same modifications to
% metadata that are done at the end of processNSx().
% (4) If NSx.Data is made of a single matrix (no cell structure), then the
% function performs no operations.
%
% INPUTS
% NSx - a structure created by the openNSx() function found within the
% Blackrock NMPK toolbox.
%
% OUTPUTS
% NSx - a modified version of the input NSx structure. Modifications will
% include concatenation of signal data into a single matrix.
%
% Author: Joshua Adkinson

syncSampleWindow = 1:120;
persistent mode

if ~iscell(NSx.Data)
    return
end

if isempty(mode)
    beep
    mode = questdlg({'The NSx data structure is composed of more than one cell. How would you like to handle this discrepancy?',[],...
        'Note: Your selection will be stored for future use until the function is cleared.'},...
        'Data Discrepancy','Concatenate','Zero Pad','NaN Pad','Concatenate');
    if isempty(mode)
        warning(['User did not select a method for handling data discrepancy. Defaulting to Concatenating. Type ''clear ',fn.name,'''  to reset.'])
        mode = 'Concatenate';
    end
end

% Check for existence and position of synchronization event.
[~,iA] = intersect(NSx.MetaTags.Timestamp,syncSampleWindow);
if ~isempty(iA)
    if iA>2
        fprintf(['Timestamp elements recognized as part of synchronization setup.\nIgnoring first ',num2str(iA-1),' data cells (',num2str(sum(NSx.MetaTags.DataDurationSec(1:iA))),' seconds trimmed from beginning of dataset).\n\n'])
    else
        fprintf(['Timestamp elements recognized as part of synchronization setup.\nIgnoring first data cell (',num2str(NSx.MetaTags.DataDurationSec(1:iA-1)),' seconds trimmed from beginning of dataset).\n\n'])
    end
    NSx.Data = NSx.Data(iA:end);
    NSx.MetaTags.Timestamp(1:iA) = [];
    if length(NSx.Data)==1
        NSx.Data = vertcat(NSx.Data{:});
        return
    end
end

% Stitch data by User's choice
if strcmp(mode,'Concatenate')
    NSx.Data = horzcat(NSx.Data{:});
else
    switch mode
        case 'Zero Pad'
            paddingFunctionHandle = @zeros;
        case 'NaN Pad'
            paddingFunctionHandle = @nan;
    end
    timestamp = NSx.MetaTags.Timestamp;
    padding = diff(timestamp/(NSx.MetaTags.TimeRes/NSx.MetaTags.SamplingFreq))-NSx.MetaTags.DataPoints'; % Tells the number of samples lost between cells within the given Time Resolution
    if any(size(padding)==1)
        padding = padding(1);
    else
        padding = diag(padding);
    end
    nDataChunks = cell2mat(cellfun(@(x) size(x,2),NSx.Data,'Uni',0));
    nData = sum(nDataChunks)+sum(padding);
    nChan = size(NSx.Data{1},1);
    d = paddingFunctionHandle(nChan,nData);
    c = 0;
    d(:,c+(1:nDataChunks(1))) = NSx.Data{1};

    for i = 2:length(NSx.Data)
        c = sum(nDataChunks(1:i-1))+sum(padding(1:i-1));
        d(:,c+(1:nDataChunks(i))) = NSx.Data{i};
    end
    NSx.Data = d;
end

end