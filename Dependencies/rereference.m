function rereferencedData = rereference(data,method,probeIndices)
%REREFERENCE 
% CODE PURPOSE Function for rereferencing multichannel sEEG probe data
% based on a provided method
%
% INPUTS
%  data - Matrix with rows as channels and columns as time series values.
%  If only the data is provided, the function defaults to common average
%  referencing
%  method - Current supported methods are 'CAR','CMR','PAR','Laplacian',
%  and 'Bipolar'. 'None' returns the input data without rereferencing.
%  probeIndices - a cell array providing the indices of contacts on each
%  probe with respect to the provided 'data' array. This variable is
%  required when using 'Laplacian' and will change the number of rows when
%  optionally included with 'Bipolar'.
%
% OUTPUT
%  rereferencedData - the output data in the selected rereferenced format
%
% Author: Joshua Adkinson

if nargin==1
    method = 'CAR';
    probeIndices = [];
elseif nargin==2
    probeIndices = [];
end

switch method
    case 'CAR' % Common Average Rereferencing
        % Rereference CAR
        rereferencedData = data-mean(data,1);

    case 'CMR' % Common Median Rereferencing
        rereferencedData = data-median(data,1);

    case 'GAR' % Grey-matter Averaging Rereferencing
        
    case 'PAR' % Probe Average Rereferencing
        % Rereference Per Probe
        contactsPerProbe = cellfun(@length,probeIndices);
        
        if sum(contactsPerProbe)~=size(data,1)
            error('The number of contacts does not coincide with the number of channels being rereferenced')
        end
        
        % Create Probe Indexing Cell Structure
        proximalContactInd = cumsum([1; contactsPerProbe(1:end-1)]);
        distalContactInd = cumsum(contactsPerProbe);
        probeIndices=cell(length(contactsPerProbe),1);
        for i=1:length(probeIndices)
            probeIndices{i}=proximalContactInd(i):distalContactInd(i);
        end
        
        tmp1 = cellfun(@(x) mean(data(x,:),1),probeIndices,'Uni',0);
        tmp2 = cellfun(@(x,y) data(x,:)-y,probeIndices,tmp1,'Uni',0);
        rereferencedData = cat(1,tmp2{:});
        
    case 'Laplacian' % Laplacian Rereferencing
        contactsPerProbe = cellfun(@length,probeIndices);
        
        if sum(contactsPerProbe)~=size(data,1)
            error('The number of contacts does not coincide with the number of channels being rereferenced')
        end
        
        % Create Probe Indexing Cell Structure
        proximalContactInd = cumsum([1; contactsPerProbe(1:end-1)]);
        distalContactInd = cumsum(contactsPerProbe);
        probeIndices=cell(length(contactsPerProbe),1);
        for i=1:length(probeIndices)
            probeIndices{i}=proximalContactInd(i):distalContactInd(i);
        end
        outerContactInd = [proximalContactInd distalContactInd];
        outerContactInd = sort(outerContactInd(:));
        
        % Rereference Laplacian
        ind = setdiff(1:size(data,1),outerContactInd);
        a = zeros(size(data));
        b = a;
        a(ind,:) = data(ind-1,:);
        b(ind,:) = data(ind+1,:);
        c = zeros(size(data));
        c(proximalContactInd,:) = data(proximalContactInd+1,:);
        c(distalContactInd,:) = data(distalContactInd-1,:);
        rereferencedData = data-((a+b)/2)-c;
        

%         Above Method approximately 3x faster but requires 2x memory
%         rereferencedData = zeros(size(data));
%         for i=1:length(probeIndices)
%             for j=1:length(probeIndices{i})
%                 if j==1
%                     rereferencedData(probeIndices{i}(j),:)=data(probeIndices{i}(j),:)-data(probeIndices{i}(j)+1,:);
%                 elseif j==length(probeIndices{i})
%                     rereferencedData(probeIndices{i}(j),:)=data(probeIndices{i}(j),:)-data(probeIndices{i}(j)-1,:);
%                 else
%                     rereferencedData(probeIndices{i}(j),:)=data(probeIndices{i}(j),:)-mean(data([probeIndices{i}(j)-1,probeIndices{i}(j)+1],:),1);
%                 end
%             end
%         end


    case 'Bipolar'
        %Rereference Bipolar
        rereferencedData = diff(data);
        if ~isempty(probeIndices)
            contactsPerProbe = cellfun(@length,probeIndices);
            if sum(contactsPerProbe)~=size(data,1)
                error('The number of contacts does not coincide with the number of channels being rereferenced')
            end
            distalContactInd = cumsum(contactsPerProbe);
            rereferencedData(distalContactInd,:) = [];
        end

    case 'None'
        rereferencedData = data;
        
end

end