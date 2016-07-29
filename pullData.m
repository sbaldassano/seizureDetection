%this is a script to pull data from portal records and assemble clips to
%mimic the format of the kaggle seizure detection competition

function pullData(subjNum,dataset)
    load kaggleData.mat;
    ptName = kaggleData(subjNum).ID;
    % Make a directory for this patient's data
    if exist(ptName,'dir')
        rmdir(ptName,'s')
    end
        mkdir(ptName);
   
    % Get the start and stop times of the seizures
    [~, timesUsec, ~] = getAnnotations(dataset, kaggleData(subjNum).SzLayerName);
    
    startTimes = timesUsec(:,1);
    stopTimes = timesUsec(:,2);

    % Get the data sampling rate. If the sampling rate is not an integer,
    % it will be rounded to have a whole number of samples in each 1-second
    % clip
    fs = dataset.sampleRate;
    fs_int = round(fs);
    
    % Derive indices of channels to use
    leads = [];
    numChan = numel(dataset.rawChannels);
    for i = 1:numChan
        temp = strfind(kaggleData(subjNum).Channels,dataset.rawChannels(i).label);
        if ~isempty(cell2mat(temp))
            leads = [leads i];
        end
    end
    
    key = {};
    
    
    % assemble channel field names 
    for i = 1:numel(leads)
        field = matlab.lang.makeValidName(['X_' dataset.rawChannels(leads(i)).label '_']);
        channels.(field) = dataset.rawChannels(leads(i)).label;
    end
    
    trainSzClipNum = 0;
    testClipNum = 0;
    
    szLengths = [];
    numIctal = kaggleData(subjNum).numTrainSz + kaggleData(subjNum).numTestSz;
    numSkip = length(kaggleData(subjNum).skipIdx);
    skipCounter = 0;
    
    % iterate through all training and testing seizures (skipping those
    % detailed in the kaggleData.mat file if desired)
    for i = 1:numIctal+numSkip
        if any(kaggleData(subjNum).skipIdx==i)
            skipCounter = skipCounter + 1;
            continue
        end
	pulled = false;
	while ~pulled
		try	
        		% pull data
                curData = dataset.getvalues(startTimes(i)/1e6*fs:stopTimes(i)/1e6*fs,leads);
        		pulled = true;
		catch
			fprintf('ictal data grab failed on subject %g, trying again\n',subjNum);
		end
    end
        numClips = floor(size(curData,1)/fs_int);
        szLengths = [szLengths numClips];
        % Determine if clip is a training or testing seizure
        if i-skipCounter <= kaggleData(subjNum).numTrainSz
            trainingSz = 1;
            tempClipNum = trainSzClipNum;
        else 
            trainingSz = 0;
            tempClipNum = testClipNum;
        end
        % clip the seizure into one-second clips and assemble
        [key,netClips] = clipIctalData(curData',fs_int,channels,ptName,numClips,trainingSz,tempClipNum,key); 
        
        if trainingSz
            trainSzClipNum = trainSzClipNum + netClips;
        else
            testClipNum = testClipNum + netClips;
        end
    end
    
    
    % now we need to pull interictal clips (need to be far from all
    % seizures). Currently set up to pull 7 times as many interictal clips
    % as seizure clips
    numInterictal = numIctal*7;
    timesUsed = [];
    
    trainInterictalClipNum = 0;
    
    for i = 1:numInterictal
        % pic a starting time. Make sure it is far away from other seziures
        % and other interictal clips. Make sure that there are no NaNs in
        % the pull and that no leads are all 0.
        pulled = false;
        while ~pulled
            
            if i <= kaggleData(subjNum).numTrainSz*7 % if it is a training seg, pull from the training part of the record
                temp_start = randi([1 round(startTimes(kaggleData(subjNum).numTrainSz)/1e6)],1);
                trainingClip = 1;
            else
                %If it is a testing seg, pull from the testing part of the
                %record
                  temp_start = randi([round(stopTimes(kaggleData(subjNum).numTrainSz)/1e6) round(dataset.rawChannels(1).get_tsdetails.getDuration/1e6-mean(szLengths))],1);
                trainingClip = 0;
            end
                     
            % check if time is close to a seizure or a previous time
            % Need to be 3 hours away from a seizure and 1/2 hour from other
            % clip
            tooClose = false;
            for j = 1:numIctal
                if abs(temp_start-startTimes(j)/1e6) < 3*60*60 || abs(temp_start-stopTimes(j)/1e6) < 3*60*60
                    fprintf('too close to a seizure\n')
                    tooClose = true;
                    break
                end
            end
            if tooClose
                continue
            end
            
            tooClose = false;
            for j = 1:size(timesUsed)
                if abs(temp_start-timesUsed(j)) < 0.5*60*60
                    fprintf('too close to another clip\n')
                    tooClose = true;
                    break
                end
            end
            if tooClose
                continue
            end
            
            % after grabbing, see if there is any missing data (NaNs)
            haveData = false;
            while ~haveData
                try
                        curData = dataset.getvalues(temp_start*fs:(temp_start+mean(szLengths))*fs,leads);
                        haveData = true;
                catch
                    fprintf('Data grab failed on interictal segment in subject %g, trying again\n',subjNum);
                end
            end    
            if any(any(isnan(curData)))
                fprintf('grab had missing data\n')
                continue 
            end
            % if any leads are all zero, try again
            if any(all(curData==0))
                fprintf('grab had an all-zero lead\n')
                continue
            end
            % keep track of where pulls came from
           timesUsed = [timesUsed temp_start];
            
            numClips = floor(size(curData,1)/fs_int);
            if trainingClip
                tempClipNum = trainInterictalClipNum;
            else 
                tempClipNum = testClipNum;
            end
            % clip the data into one-second clips and assemble
            [key, netClips] = clipInterictalData(curData',fs_int,channels,ptName,numClips,trainingClip,tempClipNum,key);   
            if trainingClip
                trainInterictalClipNum = trainInterictalClipNum + netClips;
            else
                testClipNum = testClipNum + netClips;
            end
            pulled = true;
        end
    end
    % save the answer key
    save([ptName '/' ptName '_key.mat'],'key');
    
end


function [key,netClips] = clipIctalData(curData,fs,channels,ptName,numClips,trainingSz,tempClipNum,key)
    % will clip the data into one second chunks and then save each of them
    % in the appropriate format
    freq = fs; 
    pos = 0;
    skippedForNans = 0;
    for c = 1:numClips
        data = curData(:,pos+1:pos+fs);
        pos = pos+fs;
        % If the one-second clips has NaNs, don't use it
        if any(any(isnan(data)))
            skippedForNans = skippedForNans + 1;
            continue
        end
        % If the one-second clip has a "dead" lead, don't use it
        if any(all(data'==0))
            skippedForNans = skippedForNans + 1;
            continue
        end
        data = data - repmat(mean(data,2),1,size(data,2)); %mean normalize each channel signal within the clip.
        latency = c-1;
        
        % Save data in a format mimicking the kaggle competition
        if trainingSz
            save([ptName '/' ptName '_ictal_segment_' num2str(c-skippedForNans+tempClipNum) '.mat'], 'data','channels','freq','latency');
        else
            save([ptName '/' ptName '_test_segment_' num2str(c-skippedForNans+tempClipNum) '.mat'], 'data','channels','freq');
            if latency < 15
                early = 1;
            else
                early = 0;
            end
            key = [key; {[ptName '_test_segment_' num2str(c-skippedForNans+tempClipNum) '.mat'] 1 early}];
        end
    end
    netClips = numClips - skippedForNans;
end

function [key,netClips] = clipInterictalData(curData,fs,channels,ptName,numClips,trainingClip,tempClipNum,key)
    % will clip the data into one second chunks and then save each of them
    % in the appropriate format
    freq = fs;   
    pos = 0;
    skippedForZeros = 0;
    for c = 1:numClips
        data = curData(:,pos+1:pos+fs);
        pos = pos+fs;
        if any(all(data'==0))
            skippedForZeros = skippedForZeros + 1;
            continue
        end
        data = data - repmat(mean(data,2),1,size(data,2)); %mean normalize each channel signal within the clip.
        if trainingClip
            save([ptName '/' ptName '_interictal_segment_' num2str(c-skippedForZeros+tempClipNum) '.mat'], 'data','channels','freq');
        else
            save([ptName '/' ptName '_test_segment_' num2str(c-skippedForZeros+tempClipNum) '.mat'], 'data','channels','freq');
            key = [key; {[ptName '_test_segment_' num2str(c-skippedForZeros+tempClipNum) '.mat'] 0 0}];
        end
    end
    netClips = numClips - skippedForZeros;
end
        
    
