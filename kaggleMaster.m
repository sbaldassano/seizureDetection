% This is a master program to assemble data for use of the kaggle seizure
% detection competition winning algorithms

% Inputs:
% kaggleData.mat file containing subject information (see README)

% Requires latest version of the IEEG toolbox to be added to path
% (available from www.ieeg.org)
% Replace 'USERID' and 'USERID_ieeglogin.bin' with your own IEEG portal
% login information as described on ieeg.org

% Outputs:
% 1-second clips of ictal, interictal, and testing data organized by
% subject directories
% key.csv file containing the correct classifications of the test data
% according to the provided annotations

% Note that this pipeline assembles data from the IEEG portal, but does not
% automatically run the classification algorithms. Once the file structure
% is assembled, the desired algorithms can be easily run according to the
% instructions on their github pages (see README).

load kaggleData.mat;
masterKey = {'clip' 'seizure' 'early'};
for subjNum = 1:numel(kaggleData)
    fprintf(['running for subject %g overall, %g training sz for pt ' kaggleData(subjNum).ID '\n'],subjNum,kaggleData(subjNum).numTrainSz);
    % Begin a IEEG session for the subject
    if ~exist('session','var')
	session = IEEGSession(kaggleData(subjNum).IEEG, 'USERID', 'USERID_ieeglogin.bin');
    else
	session = openDataSet(session,kaggleData(subjNum).IEEG);
    end
    dataset = session.data(end);
   
    % Pull the data and assemble for the desired patient
    pullData(subjNum,dataset);
    fprintf('All data clips downloaded from Portal and organized\n');
    % Add the answer key for this subject to the master key
    ptName = kaggleData(subjNum).ID;
    cd(ptName);
    load([ptName '_key.mat']);
    masterKey = [masterKey; key];
    delete([ptName '_key.mat']);
    cd ..;
    % Publish the master key as a .csv file
    cell2csv('key.csv',masterKey);
end

fprintf('Final key generated\n');
fprintf('done\n');
