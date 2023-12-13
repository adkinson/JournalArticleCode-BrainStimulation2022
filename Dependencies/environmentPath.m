function path = environmentPath(type,subject,task)
%ENVIRONMENTPATH a wrapper function for file paths
%
% CODE PURPOSE A wrapper for file paths written out by the user, similar to
% utilizing environment variables. It's expected that this function would
% be different based on the needs of the user.
%
% INPUT
% type - the name of the path the user wishes to utilize
%  OPTIONAL - examples of other user inputs into function
%   subject - subject ID, needed only for certain file paths
%   task - task name, needed only for certain file paths
%
% OUTPUT
% path - a filepath from the list of options below
%
% Author: Joshua Adkinson

switch type
    case 'DataServer'
        path = fullfile('Volumes','bcm-neurosurgery-ecog','ECoG_Data');
    case 'DataLocal'
        path = fullfile('Users','adkinson','Desktop','DATA');
    case 'Analysis'
        path = fullfile('Users','adkinson','Documents','MATLAB','Data Analysis');
    case 'Meta'
        path = fullfile('Volumes','bcm-neurosurgery-ecog','ECoG_Data',[subject,'Datafile'],'IMG');
    case 'Timing'
        path = fullfile('Users','adkinson','Documents','MATLAB','Data Analysis',task,subject,'Timing');
    case 'EpochedData'
        path = fullfile('Users','adkinson','Documents','MATLAB','Data Analysis',task,subject,'EpochedData');
end

path = [filesep,path];

end