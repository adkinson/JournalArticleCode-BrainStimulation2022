function NSx = processNSx(NSx)
%PROCESSNSX Handles Blackrock NSx structure issues related to packet loss
%and synchronization.
% 
% CODE PURPOSE
% (1) Detect in the NSx structure indicators for packet loss and/or
% synchronization performed between two Blackrock NSPs
% (2) Stitch together multiple data cells into a single matrix in a manner
% specified by the user.
% (3) Convert the data from int to double in appropriate units.
% 
% SYNTAX 
% NSx = processNSx(NSx)
% 
% DESCRIPTION
% processNSx() is designed to detect if a packet loss, pause, or
% synchronization event occured within the provided NSx data structure by
% utilizing the 'Timestamp' values provided within each Blackrock NSx file
% structure. In the event that a synchronization event is recognized, the
% code will attempt to find the accompanying NSx file structure and
% concatenate these two structures into one larger NSx structure with all
% relevant structure fields modified to match the change. Synchronization
% and packetloss/pause events also cause a temporal gap within the
% datastream. Separate datastreams will be concatenated via a few possible
% options that can be chosen by the user. For NSx structures with a
% detected synchronization event and recognized companion file,
% concatenation will occur via (1) zero padding or (2) NaN padding the
% missing data values. For concatenation of non-synchronization events, the
% user can choose (1) no padding, (2) zero padding, or (3) NaN padding.
% Note: To allow for batch handling of multiple NSx filesets, the choices
% made by the user will persist until a call to 'clear processNSx'. Lastly,
% the resulting data is converted from int to double with units determined
% by the NSx.ElectrodesInfo.Resolution subfield.
%
% INPUTS
% NSx - a structure created by the openNSx() function found within the
% Blackrock NMPK toolbox.
% 
% OUTPUTS 
% NSx - a modified version of the input NSx structure.
% Modifications will include concatenation of signal data into a single
% matrix (along with possible concatenation of a second NSx dataset in the
% event of a synchronization event), conversion of each row of data into
% its appropriate measurement space (mV/uV),and revisions to relevant
% metadata.
% 
% Author: Joshua Adkinson

fn = dbstack;
syncSampleWindow = 1:120;
persistent modeMulti trimOrPad combineData
if isempty(combineData)
    beep
    tmp = questdlg({'This program can combine Blackrock files within the same folder which have similar names and file extensions into a singlur structure. Would you like to use this feature?',[],...
                'Note: Your selection will be stored for future use until the function is cleared.'},...
                'Combine Data','Yes','No','Yes');
    combineData = strcmp(tmp,'Yes');
end
if length(NSx.MetaTags.Timestamp)~=1
    % Detect Synchronized NSP Data and Find Complementary Files
    if ~isempty(intersect(NSx.MetaTags.Timestamp,syncSampleWindow)) && combineData
        fprintf('Detecting NSP Synchronization Flag.\n')
        fprintf(['Searching for complementary NSx files in folder:\n',NSx.MetaTags.FilePath,'\n\n'])
        anchorFilename = [NSx.MetaTags.Filename,NSx.MetaTags.FileExt];
        anchorFilenamePattern = regexprep(NSx.MetaTags.Filename,'NSP-*[12]','NSP-*[12]');
        anchorFilePattern = [anchorFilenamePattern,NSx.MetaTags.FileExt];
        tmp = dir(NSx.MetaTags.FilePath);
        files = {tmp.name}';
        bool1 = ~cellfun(@isempty,regexp(files,anchorFilePattern));
        bool2 = cellfun(@isempty,regexp(files,anchorFilename));
        idx = find(bool1+bool2==2);
        if length(idx)>1
            idx1 = listdlg('ListString',files(bool),'PromptString',{'Multiple Possible Matches Detected.',...
                'Please select the correct file(s).','',['Original File: ',anchorFilename]},...
                'SelectionMode','multiple','ListSize',[240 300]);
            idx = idx(idx1);
            
            fprintf('The data from the selected file(s) will be added to our original data structure:\n')
            for i = 1:length(idx)
                fprintf([int2str(i),'. ',files{idx(i)},'\n'])
            end
        elseif length(idx)==1
            fprintf(['Complementary NSx file found: ',files{idx},'\n\n']);
        else
            fprintf(['No Complementary NSx file found for ',anchorFilename,'.\nTreating as independent NSx structure.\n\n']);
            NSx = processSingleNSx(NSx);
            NSx.Data = double(NSx.Data).*[NSx.ElectrodesInfo.Resolution]';
            NSx.MetaTags.DataPoints = size(NSx.Data,2);
            NSx.MetaTags.DataPointsSec = size(NSx.Data,2)/NSx.MetaTags.SamplingFreq;
            NSx.MetaTags = rmfield(NSx.MetaTags,'Timestamp');
            NSx.MetaTags = rmfield(NSx.MetaTags,'DataDurationSec');
            NSx.MetaTags = orderfields(NSx.MetaTags);
            NSx = rmfield(NSx,'RawData');
            NSx = orderfields(NSx,{'Data','ElectrodesInfo','MetaTags'});
            return
        end
        
        if isempty(modeMulti)
            beep
            modeMulti = questdlg({'Combining synchronized data (and fixing any issues related to packet loss) requires some type of data padding to properly align all of the data. What type of padding would you like to use?',[],...
                'Note: Your selection will be stored for future use until the function is cleared.'},...
                'Data Discrepancy','Zero Pad','NaN Pad','Zero Pad');
            if isempty(modeMulti)
                warning(['User did not select a method for padding data. Defaulting to Zero Padding. Type ''clear ',fn.name,'''  to reset.'])
                modeMulti = 'Zero Pad';
            end
        end
        
        % Load complementary files and aggregate relevent data into
        % original structure
        timeStamps = {NSx.MetaTags.Timestamp};
        dataPoints = {NSx.MetaTags.DataPoints};
        NSx.Data = {NSx.Data};
        for i = 1:length(idx)
            tmpNSx = openNSx(fullfile(NSx.MetaTags.FilePath,files{idx(i)}));
            NSx.MetaTags.ChannelCount = cat(2,NSx.MetaTags.ChannelCount,tmpNSx.MetaTags.ChannelCount);
            NSx.MetaTags.ChannelID = cat(1,NSx.MetaTags.ChannelID,tmpNSx.MetaTags.ChannelID);
            NSx.MetaTags.Comment = cat(1,NSx.MetaTags.Comment,tmpNSx.MetaTags.Comment);
            NSx.MetaTags.Filename = [NSx.MetaTags.Filename,'+',tmpNSx.MetaTags.Filename];
            NSx.ElectrodesInfo = [NSx.ElectrodesInfo,tmpNSx.ElectrodesInfo];
            NSx.Data = cat(1,NSx.Data,{tmpNSx.Data});
            timeStamps = cat(1,timeStamps,{tmpNSx.MetaTags.Timestamp});
            dataPoints = cat(1,dataPoints,{tmpNSx.MetaTags.DataPoints});
        end
        
        % Which cell starts synchronizing within each dataset?
        [~,initCell] = cellfun(@(x) intersect(x,syncSampleWindow),timeStamps,'Uni',0);
        NSx.Data = cellfun(@(x,y)  x(y:end),NSx.Data,initCell,'Uni',0); % Remove the previous cells
        timeStamps = cellfun(@(x,y) x(y:end),timeStamps,initCell,'Uni',0);
        dataPoints = cellfun(@(x,y) x(y:end),dataPoints,initCell,'Uni',0);
        % Which dataset starts the synchronization?
        tmp = cellfun(@(x) intersect(x,1),timeStamps,'Uni',0);
        tmp = cellfun(@isempty,tmp,'Uni',0);
        syncCell = ~[tmp{:}];
%         % Beats before synchronization occurred
%         trimCell = cellfun(@(x) intersect(x,syncSampleWindow),timeStamps,'Uni',0);
%         trim = trimCell(~syncCell);
%         % Trim off initial unsynchronized data from primary sychronization
%         % data structure
%         NSx.Data{syncCell}{1} = NSx.Data{syncCell}{1}(:,trim{1}+1:end); % trim+1 for reasons.... blackrock reasons...
%         % Adjust timeStamps for adjusting potential packet loss issues
%         timeStamps{syncCell} = timeStamps{syncCell}-timeStamps{syncCell}(1);
%         timeStamps{~syncCell} = timeStamps{~syncCell}-timeStamps{~syncCell}(1);
%         timeStamps = cellfun(@(x) x+1,timeStamps,'Uni',0);
        % Beats before synchronization occurred
        padCell = cellfun(@(x) intersect(x,syncSampleWindow),timeStamps,'Uni',0);
        padAmount = padCell(~syncCell);
        % Zero-pad unsynchronized data from secondary synchronization data
        % structure
        padding = zeros(size(NSx.Data{~syncCell}{1},1),padAmount{1}); %Pad the same number as the timestamp...for blackrock reasons...
        NSx.Data{~syncCell}{1} = [padding NSx.Data{~syncCell}{1}];
        % Adjust timeStamps for adjusting potential packet loss issues
        timeStamps{~syncCell} = 1;
        
        
        % Check and adjust for packet loss in either NSP dataset
        packetLoss = cellfun(@length,NSx.Data)>1;
        if any(packetLoss)
            pktLssIdx = find(packetLoss==1);
            
            % Fix alignment between NSP datasets with padding
            for j = 1:length(pktLssIdx)
                switch modeMulti
                    case 'Zero Pad'
                        padding = diff(timeStamps{pktLssIdx(j)}/(NSx.MetaTags.TimeRes/NSx.MetaTags.SamplingFreq))-dataPoints{pktLssIdx(j)}'; % Tells the number of samples lost between cells within the given Time Resolution
                        if any(size(padding)==1)
                            padding = padding(1);
                        else
                            padding = diag(padding);
                        end
                        if any(padding-round(padding)~=0)
                            t = mod(timeStamps{pktLssIdx(j)}-1,(NSx.MetaTags.TimeRes/NSx.MetaTags.SamplingFreq));
                            warning('The sampling phase in one or more cell structures deviates from the original sampling phase. Timestamp will be rounded to the nearest digit.')
                            for i = 1:length(t)
                                fprintf(['Cell ',int2str(i),': ',num2str(t(i)/NSx.MetaTags.TimeRes*1e6),' microseconds out-of-phase\n']) %Note: Needs to be corrected
                            end
                            padding = round(padding);
                        end
                        nDataChunks = cell2mat(cellfun(@(x) size(x,2),NSx.Data{pktLssIdx(j)},'Uni',0));
                        nData = sum(nDataChunks)+sum(padding);
                        nChan = size(NSx.Data{pktLssIdx(j)}{1},1);
                        d = zeros(nChan,nData);
                        c = 0;
                        d(:,c+(1:nDataChunks(1))) = NSx.Data{pktLssIdx(j)}{1};
                        
                        for i = 2:length(NSx.Data)
                            c = sum(nDataChunks(1:i-1))+sum(padding(1:i-1));
                            d(:,c+(1:nDataChunks(i))) = NSx.Data{pktLssIdx(j)}{i};
                        end
                        NSx.Data{pktLssIdx(j)} = d;
                    case 'NaN Pad'
                        padding = diff(timeStamps{pktLssIdx(j)}/(NSx.MetaTags.TimeRes/NSx.MetaTags.SamplingFreq))-dataPoints{pktLssIdx(j)}'; % Tells the number of samples lost between cells within the given Time Resolution
                        if any(size(padding)==1)
                            padding = padding(1);
                        else
                            padding = diag(padding);
                        end
                        if any(padding-round(padding)~=0)
                            t = mod(timeStamps{pktLssIdx(j)}-1,(NSx.MetaTags.TimeRes/NSx.MetaTags.SamplingFreq));
                            warning('The sampling phase in one or more cell structures deviates from the original sampling phase. Timestamp will be rounded to the nearest digit.')
                            for i = 1:length(t)
                                fprintf(['Cell ',int2str(i),': ',num2str(t(i)/NSx.MetaTags.TimeRes*1e6),' microseconds out-of-phase\n']) %Note: Needs to be corrected
                            end
                            padding = round(padding);
                        end
                        nDataChunks = cellfun(@(x) size(x,2),NSx.Data{pktLssIdx(j)},'Uni',0);
                        nData = sum(nDataChunks)+sum(padding);
                        nChan = size(NSx.Data{pktLssIdx(j)}{1},1);
                        d = nan(nChan,nData);
                        c = 0;
                        d(:,c+(1:nDataChunks(1))) = NSx.Data{pktLssIdx(j)}{1};
                        
                        for i = 2:length(NSx.Data)
                            c = sum(nDataChunks(1:i-1))+sum(padding(1:i-1));
                            d(:,c+(1:nDataChunks(i))) = NSx.Data{pktLssIdx(j)}{i};
                        end
                        NSx.Data{pktLssIdx(j)} = d;
                end
            end
        end
        
        NSx.Data = vertcat(NSx.Data{:});
        
        % Almost there! Time to check for differences in data length and
        % either trim or pad the data
        samplesPerSet = cell2mat(cellfun(@(x) size(x,2),NSx.Data,'Uni',0));
        if length(unique(samplesPerSet))>1
            if isempty(trimOrPad)
                beep
                trimOrPad = questdlg({'The combined NSP data structures are not the same length. How would you like to handle this discrepancy?',[],...
                    'Note: Your selection will be stored for future use until the function is cleared.'},...
                    'Data Discrepancy','Trim','Zero Pad','NaN Pad','Trim');
                if isempty(trimOrPad)
                    warning(['User did not select a method for handling data discrapancy. Defaulting to Trimming. Type ''clear ',fn.name,'''  to reset.'])
                    trimOrPad = 'Trim';
                end
            end

            minSam = min(samplesPerSet);
            maxSam = max(samplesPerSet);
            minIdx = find(samplesPerSet~=maxSam);
            maxIdx = find(samplesPerSet~=minSam);
            switch trimOrPad
                case 'Trim'
                    for j = 1:length(maxIdx)
                        NSx.Data{maxIdx(j)} = NSx.Data{maxIdx(j)}(:,1:minSam);
                    end
                case 'Zero Pad'
                    for j = 1:length(minIdx)
                        zeroPad = zeros(size(NSx.Data{minIdx(j)},1),maxSam-samplesPerSet(minIdx(j)));
                        NSx.Data{minIdx(j)} = cat(2,NSx.Data{minIdx(j)},zeroPad);
                    end
                case 'NaN Pad'
                    for j = 1:length(minIdx)
                        nanPad = nan(size(NSx.Data{minIdx(j)},1),maxSam-samplesPerSet(minIdx(j)));
                        NSx.Data{minIdx(j)} = cat(2,NSx.Data{minIdx(j)},nanPad);
                    end
            end
        end

        % Finally, let's combine all of the data into one big matrix
        NSx.Data = cat(1,NSx.Data{:});
        
        
    else % Multiple NSPs not detected. Single NSx mode.
        NSx = processSingleNSx(NSx);
    end
    
end
NSx.Data = double(NSx.Data).*[NSx.ElectrodesInfo.Resolution]';
NSx.MetaTags.DataPoints = size(NSx.Data,2);
NSx.MetaTags.DataPointsSec = size(NSx.Data,2)/NSx.MetaTags.SamplingFreq;
NSx.MetaTags = rmfield(NSx.MetaTags,'Timestamp');
NSx.MetaTags = rmfield(NSx.MetaTags,'DataDurationSec');
NSx.MetaTags = orderfields(NSx.MetaTags);
NSx.ChannelDim = 1;
NSx = rmfield(NSx,'RawData');
NSx = orderfields(NSx,{'Data','ElectrodesInfo','MetaTags','ChannelDim'});
end