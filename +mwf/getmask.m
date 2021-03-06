% Create or load an artifact mask for the input EEG data.
%
% INPUTS:
%   y           raw EEG data (channels x samples)
%   fs          EEG data sample rate                
%   cacheID     specifier to identify cached mask
%   cachepath   path to cache folder where masks can be saved
%   redo        flag:   if 1, a new mask will always be generated
%                       if 0, a new mask is generated only if no cache is present
%   mode        GUI/toolbox to use for artifact marking
%                       0: EEGLAB (eegplot)
%                       1: EyeBallGUI
%
% OUTPUTS: 
%   mask    markings of artifacts in y (1 x samples)
%           The mask contains 1's in marked artifact segments and 0's elsewhere.
%
% USAGE:
% Only the first two inputs are required, the rest is optional.
%
% You can make use of the caching functionality to save your artifact
% masks to disk so they can be reused later. In order to retrieve the masks
% in the cache, an ID ('cacheID') must be provided. 
% If no cachepath is specified, the masks will be saved in the current 
% working directory.
% The redo input can be set to 1 if you wish to redo (overwrite) an
% existing mask saved in the cache. 
%
% EXAMPLES:
% Assume there is some EEG data 'EEG' (channels x samples) and the
% samplerate 'fs' in the matlab workspace.
%
%   mask = mwf.getmask(EEG, fs)
%   Create a mask. It is not saved to the cache.
%
%   mask = mwf.getmask(EEG, fs, 'subject1')
%   Create a mask and save it in the current working directory as 'subject1_mask.mat'. 
%   If this file already existed in the current directory, it is loaded.
%
%   mask = mwf.getmask(EEG, fs, 'subject1', 'C:/users/cache')
%   Create a mask and save it in 'C:/users/cache' as 'subject1_mask.mat'. 
%   If this matfile already existed in that directory, it is loaded instead.
%
%   mask = mwf.getmask(EEG, fs, 'subject1', 'C:/users/cache', 1)
%   Regardless of whether as 'subject1_mask.mat' exists in 'C:/users/cache', 
%   a new mask is generated and saved to cache. If it already existed, it is overwritten. 
%
% Toolbox references:
%   MWF toolbox manual: https://github.com/exporl/mwf-artifact-removal
%   EEGLab: https://sccn.ucsd.edu/eeglab/
%   EyeBallGUI: http://eyeballgui.sourceforge.net
%
% Author: Ben Somers, KU Leuven, Department of Neurosciences, ExpORL
% Correspondence: ben.somers@med.kuleuven.be

function [mask] = getmask(y, fs, cacheID, cachepath, redo, mode)

% input validation
if (nargin < 6)
    mode = 0; % default: EEGLAB plotting
end
if (nargin < 5)
    redo = 0; % default: load existing mask from cache, if non-existing, create a new one
end
if (nargin < 4)
    cachepath = pwd; % default: if no cache path is given, save masks in current directory
end
if (nargin < 3)
    cacheID = ''; % default: if no ID is given, the mask will not be saved to cache
end
if (nargin < 2)
    error('EEG samplerate is required for plotting')
end
if (nargin < 1) || (nargin > 6)
    error('Invalid number of inputs.')
end

if isempty(cacheID);
    maskpath = '';
else
    maskpath = fullfile(cachepath, [cacheID '_mask.mat']);
end

if (~exist(maskpath, 'file') || redo)
    if (~mode) % Use EEGlab
        eegplot(y, 'srate', fs, 'winlength', 10, ...
            'tag', 'eegplot_marks', 'command', 'get_mask_eeglab', 'butlabel', 'SAVE MARKS');
        h = findobj(0, 'tag', 'eegplot_marks');
        [FIGexist, TMPREJexist] = updateEegplotStatus(h);
        if TMPREJexist % clear global variable for safety
            evalin('base',['clear ', 'TMPREJ'])
        end
        
        % Wait for variable to be created in base workspace by EEGLAB after marking
        while(~TMPREJexist && FIGexist)
            [FIGexist, TMPREJexist] = updateEegplotStatus(h);
            if(~FIGexist && ~TMPREJexist) % eegplot closed without mask
                warning('Selection of artifact segments aborted by user. No new mask will be saved.')
                mask = [];
                return
            elseif(~FIGexist && TMPREJexist) % eegplot closed by clicking save mask
                break
            elseif(FIGexist && TMPREJexist) % mask exists while figure open, impossible
                error('Error clearing eegplot global variable TMPREJ')
            else % figure open & no mask yet
                pause(1);
                continue
            end
        end
        markings = evalin('base','TMPREJ');
        evalin('base',['clear ', 'TMPREJ']) %clear global
        
        %build mask from markings
        mask = zeros(1,size(y,2));
        for i = 1:size(markings,1)
            mask(:,floor(markings(i,1)):ceil(markings(i,2))) = 1;
        end        
    else % use EyeBallGUI
        % Create .mat file to be loaded by EyeBallGUI
        save('TRAINING_DATA.mat','FileEEGdata','FileEEGsrate')
    
        % Launch EyeBallGUI
        EyeBallGUI
        % Wait until the "Bad" file exists with markings in the directory. If one
        % exists already, delete it
        if(exist('TRAINING_DATABad.mat','file'))
            delete('TRAINING_DATABad.mat');
        end
        while(~exist('TRAINING_DATABad.mat','file'))
            pause(1);
        end

        % Close GUI after markings are saved and clean up backup files
        close all force
        rmdir('EyeBallGUI_BackUp','s')
        delete('EyeBallGUIini.mat')

        % Extract marked artifact segments from markings .mat file
        load('TRAINING_DATABad.mat');
        mask = isnan(EEGmask);
        mask = sum(mask,1);
        mask(mask>0) = 1;
        
        cleanup_EyeBallGUI; 
    end
    if ~isempty(maskpath)        
        save(maskpath, 'mask');
    end
else % mask already exists
    S = load(maskpath);
    mask = S.mask;
end

end

function [FIGexist, TMPREJexist] = updateEegplotStatus(h)
% return if eegplot still exist & if marking global variable exists
% INPUT: eegplot function handle
    W = evalin('base','whos');
    TMPREJexist = any(strcmp('TMPREJ',{W(:).name}));
    FIGexist = ishghandle(h);
end

function get_mask_eeglab() %#ok<DEFNU>
% Dummy function for eegplot button callback
    disp('Generating the mask from EEGLAB markings...');
end

function cleanup_EyeBallGUI
% Remove generated backup and initialization files created by EyeBallGUI 
% in the current working directory.
if exist('EyeBallGUI_BackUp','dir')
    rmdir('EyeBallGUI_BackUp','s')
end

if exist('EyeBallGUIini.mat','file')
    delete('EyeBallGUIini.mat')
end

if exist('TRAINING_DATA.mat','file')
    delete('TRAINING_DATA.mat');
end

if exist('TRAINING_DATABad.mat','file')
    delete('TRAINING_DATABad.mat');
end
end
