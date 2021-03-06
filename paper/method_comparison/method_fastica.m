% Perform Independent Component Analsyis (FastICA) for artifact removal.
%
% INPUTS:
%   y       raw EEG data (channels x samples)
%   Fs      EEG data sample rate
%   cache   data identifier struct to retrieve cached components
%
% OUTPUTS: 
%   n       filtered EEG data (channels x samples)
%   d       estimated artifacts in every channel (channels x samples)
%   t       computation time (seconds)
%
% Author: Ben Somers, KU Leuven, Department of Neurosciences, ExpORL
% Correspondence: ben.somers@med.kuleuven.be

function [n, d, t] = method_fastica(y, Fs, cache)
rng(0);
tic
[ICAcomps, V, ~] = fastica(y, 'maxNumIterations', 250);
t = toc;

% check if cached components exist, otherwise ask them from user
Idx = method_cached_components(cache);
if isempty(Idx);
    eegplot(ICAcomps,'srate',Fs,'winlength',20,'dispchans',10,'spacing',20);
    Idx = input('\n Enter artifact components: ');
    method_cached_components(cache, Idx); % save entered components to cache
    close(gcf);
end

% mixing matrix, project back to sensor space
tic
V_art = V(:,Idx);
ARTcomps = ICAcomps(Idx,:);
d = V_art*ARTcomps;
n = y - d;
t = t + toc;
end


