function p = parseBIDSfilename(filename)
%PARSEBIDSFILENAME Converts files written with a 'variable-enty' format
%into a structure of variables
%
% CODE PURPOSE Take a filename written in the 'variable-entry' format and
% convert it into a structure. Fieldnames in the structure and the input
% strings associated with each field are derived from the BIDs filenaming
% structure. For example, the file 'a-3_b-5.mat' would generate a struct
% with fieldnames 'a' and 'b' with entries of '3' and '5', respectively.
% This function was inspired by a filenaming method seen in the Brain
% Imaging Data Structure (BIDS). For more information about BIDS, visit
% http://bids.neuroimaging.io/
% 
% INPUTS
% filename - a string or character array written in the 'variable-entry'
% format for filenaming.
% 
% OUTPUTS
% p - a structure that has parsed the 'variable-entry' filename into
% variables with respective entires
%
% Author: Joshua Adkinison

fmt = '([a-zA-Z0-9]+)-([a-zA-Z0-9-]+)';
tokens = regexp(filename,fmt,'tokens');
tokens = vertcat(tokens{:})';
p = struct(tokens{:});

end