function dirStruct = uigetfilesfolders(startPath,whichType,dialog)

import javax.swing.JFileChooser;

if nargin == 0 || isempty(startPath) || any(startPath == 0)
    startPath = pwd;
    whichType = 'FILES_AND_DIRECTORIES';
    dialog = 'Open';
elseif nargin == 1
    whichType = 'FILES_AND_DIRECTORIES';
    dialog = 'Open';
elseif nargin == 2
    dialog = 'Open';
end

jchooser = javaObjectEDT('javax.swing.JFileChooser', startPath);
switch whichType
    case 'FILES_ONLY'
        jchooser.setFileSelectionMode(JFileChooser.FILES_ONLY);
    case 'DIRECTORIES_ONLY'
        jchooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
    case 'FILES_AND_DIRECTORIES'
        jchooser.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
end
jchooser.setDialogTitle(dialog) 
jchooser.setMultiSelectionEnabled(true);
if ispc
    details = jchooser.getActionMap().get('viewTypeDetails');
    details.actionPerformed([]);
end

status = jchooser.showOpenDialog([]);

dirStruct = struct('name',{},'folder',{},'date',{},'bytes',{},'isdir',{},'datenum',{});
switch status
    case JFileChooser.APPROVE_OPTION
        jFile = jchooser.getSelectedFiles();
        for i=1:numel(jFile)
            dirStruct(i).name = char(jFile(i).getName);
            dirStruct(i).folder = char(jFile(i).getParent);
            dirStruct(i).isdir = jFile(i).isDirectory;
            if dirStruct(i).isdir
                dirStruct(i).bytes = 0;
            else
                dirStruct(i).bytes = jFile(i).length;
            end
            date = datetime(jFile(i).lastModified/1000,'ConvertFrom','posixtime','TimeZone','local');
            dirStruct(i).date = char(date);
            dirStruct(i).datenum = convertTo(date,'datenum');
        end
    case JFileChooser.CANCEL_OPTION
    case JFileChooser.ERROR_OPTION
        error('Error occured while picking file.');
    otherwise
        error('Error occured while picking file.');
end