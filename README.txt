README for kaggle algorithm pipeline

This document details how this pipeline can be used to apply the kaggle seizure detection winning algorithms to a dataset of your choice.

DATA PREPARATION:

Prior to using this pipeline, the data must be properly prepared and uploaded. Data must be hosted on the IEEG portal (www.ieeg.org). The IEEG portal is free EEG hosting and viewing platform that allows for cloud storage of large datasets. Users must also download the latest copy of the IEEG Matlab toolbox and include this toolbox in your path.

Once the dataset has been uploaded to the IEEG portal, the start and end times of each seizure must be manually annotated. These annotations provide the “true” labels of the data used to identify training periods and assess classification accuracy.

PREPARATION OF SUBJECT INFORMATION:

All subject information will be supplied in a .mat file (called kaggleData.mat through the code). This .mat file must contain a struct called kaggleData. This struct will have one element per subject. The struct should have the following fields:
1) ID - a user-chosen ID for this subject
2) IEEG - the name of the portal record for this subject
3) Channels - an nx1 cell array containing the names of all channels to be used. If some record channels have poor signal or significant artifact, do not include them in this array.
4) numTrainSz - the number of seizures to be used for training
5) numTestSz - the number of seizures to be used for testing
6) SzLayerName - name of the portal annotation layer used to annotate seizure starts and ends
7) skipIdx - indices of any annotated seizures to be omitted from analysis

An example .mat file is included in this repository

PIPELINE ORGANIZATION:
1) Run kaggleMaster.m script in master directory
This script requires (1) the kaggleData.mat file (2) the IEEG toolbox. The user must enter his/her user login information in the IEEGSession command.

This script will call the pullData.m script to assemble the training and testing clips and generate the answer key.

2) Run desired classification algorithms
The winning kaggle competition algorithms can be found at:
(1) https://github.com/MichaelHills/seizure-detection
(2) https://github.com/ebenolson/seizure-detection
(3) https://github.com/asood314/SeizureDetection

These algorithms will produce a .csv file of clip classifications. Alternately, the user can apply their own classification algorithm to be benchmarked against the competition winners.

3) Run the metrics script
This script will generate classification statistics and ROC curves (with AUC calculations). If the user wishes to restrict metrics to a certain subject or cohort, he/he must define the appropriate fields where designated in the script.
