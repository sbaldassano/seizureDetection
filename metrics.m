% Compute performance metrics for Kaggle algorithms
% Inputs:
% Answer key: 3 columns (clip name, seizure, and early seizure), binary (1 line of header)
% Predictions: 3 columns (clip name, seizure, and early seizure) with prediction score (1 line of header)
% Names of individual test subject (optional)
% Names of cohorts (optional)

% Outputs:
% Classification metrics x 2 (for seizure and early seizure)
% ROC curve x 2
% AUC x 2
% Performance metric

function [CPsz, CPearly, Perf] = metrics(keyFile,predsFile,subjNames,cohort)

% Read data from answer key and predictions
fprintf('Reading predictions and answer key...')
key = csvread(keyFile,1,1);
preds = csvread(predsFile,1,1);
%load('pred_avg.mat');
%preds = pred_avg;
fprintf('done.\n')

% Select only the clips that correspond to the chosen subjects or cohort (if desired)
fprintf('Reordering prediction clips to match key...')
% Get the clip indices to reorder
keyID = fopen(keyFile,'r');
keyData = textscan(keyID,'%s %f %f','HeaderLines',1,'Delimiter',', \n');
fclose(keyID);
keyClips = keyData{1};
keyClips(strcmp(keyClips,''))=[];
keyClips = squeeze(keyClips);

predID = fopen(predsFile,'r');
predData = textscan(predID,'%s %f %f','HeaderLines',1,'Delimiter',', \n');
fclose(predID);
predClips = predData{1};
predClips(strcmp(predClips,''))=[];
predClips = squeeze(predClips);

% Now if we are filtering by patient list or cohort we select the appropriate data
%%
% This section must be customized to your subject list if you would like to use it
% Example cohort and patient names are included to be replaced
% appropriately

% If using cohorts
if nargin == 4
    if strcmp(cohort,'Cohort1')
        subjNames = {'Subject1','Subject2','Subject3'};
    elseif strcmp(cohort,'Cohort2')
        subjNames = {'Subject1','Subject4','Subject5'};
    elseif strcmp(cohort,'Cohort3')
        subjNames = {'Subject6','Subject7','Subject8','Subject9','Subject10'};
    end
end

% If listing one or more subjects by ID (not using cohorts)
if nargin ==3
    subjNames = {subjNames};
end

% Select relevant clips for chosen subjects
if nargin >=3
    indicesToKeep = [];
    predToKeep = [];
    for i = 1:numel(subjNames)
        name = subjNames{i};
        indices = find(not(cellfun('isempty', strfind(keyClips,name))));
        indicesToKeep = [indicesToKeep; indices];
        predIdx = find(not(cellfun('isempty', strfind(predClips,name))));
        predToKeep = [predToKeep; predIdx];
    end
    key = key(indicesToKeep,:);
    preds = preds(predToKeep,:);
    
    keyClips = keyClips(indicesToKeep);
    predClips = predClips(predToKeep);
end

temp = [];
for i = 1:numel(keyClips)
    j = find(strcmp(predClips,keyClips{i}),1);
    temp(i,:) = preds(j,:);
end

preds = temp;
fprintf('done.\n')
%%
numClips = size(key,1);
% Make sure the key is binary
for i = 1:numClips
    if key(i,1) ~= 1
        key(i,1) = 0;
    end
end

fprintf('Computing ROC curves...')
Perf = cell(5,2);
% Get AUC and ROC
[Perf{1,1},Perf{2,1},Perf{3,1},Perf{4,1}] = perfcurve(key(:,1),preds(:,1),1);
fprintf('done seizure...')
[Perf{1,2},Perf{2,2},Perf{3,2},Perf{4,2}] = perfcurve(key(:,2),preds(:,2),1);
Perf{5,1} = (Perf{4,1} + Perf{4,2})/2;
fprintf('done early seizure.\n')

fprintf('Computing other performance metrics...')
%set up for other metrics
thresh = 0.5; % This threshold must be selected based on how sensitive (low thresh) or specific (high thresh) a result is desired
CPsz = classperf(key(:,1),'Positive',1,'Negative',0);
CPearly = classperf(key(:,2),'Positive',1,'Negative',0);
preds = preds >= thresh; 

% Get acc, sens, spec, etc.
classperf(CPsz,preds(:,1));
classperf(CPearly,preds(:,2));
fprintf('done.\n')
fprintf('Done All.\n')
end



