%% Define mouse, session numbers, and model building parameters
clear

mns = [{'JK025'},{'JK027'},{'JK030'},{'JK036'},{'JK039'},{'JK052'}];

% sns = [{'S05'},{'S02'},{'S04'},{'S02'},{'S02'},{'S05'}]; %naive
% sns = [{'S18'},{'S07'},{'S20'},{'S16'},{'S21'},{'S20'}]; %expert
% sns = [{'S04'},{'S03'},{'S03'},{'S01'},{'S01'},{'S03'}]; %naive discreteAngles
sns = [{'S19'},{'S16'},{'S21'},{'S17'},{'S23'},{'S25'}]; %expert discreteAngles
% sns = [{'S22'},{'S14'},{'S22'},{'S18'},{'S24'},{'S26'}]; %radial distance

mdlName = 'mdlDiscreteIndivTouch';
whiskDir = 'protraction'; % 'protraction' or 'all' to choose which touches to use
touchOrder = 'all'; % 'first' or 'all' to choose which touches pre-decision
yOut = 'discrete'; % can be 'ttype' (45 vs 135), 'discrete' (45:15:135) or 'choice' (lick right probability)
Xhow = 'individual'; %can be 'mean' or 'individual' so each touch is counted 


groupMdl = cell(length(mns),1); 

if strcmp(touchOrder,'first') || strcmp(Xhow,'individual')
    DmatSelect = [1:6 8:17]; %tossing touch counts since it is all ones
else
    DmatSelect = [1:17]; %feats from 1:21
end
% GLM model parameters
glmnetOpt = glmnetSet;
glmnetOpt.standardize = 0; %set to 0 b/c already standardized
glmnetOpt.alpha = 0.95;
glmnetOpt.xfoldCV = 5;
glmnetOpt.numIterations = 10;

saveDir = 'C:\Users\shires\Documents\GitHub\AngleDiscrimBehavior\matlab\datastructs\';

%%
for d = 1:length(sns)
    mouseNumber = mns{d};
    sessionNumber = sns{d};
    
    %% Load necessary files
    behaviorFolder = 'E:\SoloData';
    cd([behaviorFolder filesep mouseNumber]);
    load(['behavior_' mouseNumber '.mat']);
    
    whiskerFolder = ['E:\WhiskerVideo' filesep mouseNumber sessionNumber];
    
    bSessionNums = cellfun(@(x) x.sessionName, b,'uniformoutput',false);

    %find behavioral data matching session and load bMat
    bMatIdx = find(cell2mat(cellfun(@(x) strcmp(x,sessionNumber),bSessionNums,'uniformoutput',false)));
    behavioralStruct = b{bMatIdx};
    wfa = Whisker.WhiskerFinal_2padArray(whiskerFolder);
    
    %% Choice and ttype builder
    outcomes = BMatBuilder(behavioralStruct,wfa);
    outcomes.sessionNumber = sessionNumber;
    outcomes.mouseNumber = mouseNumber;
    %% Touch feature builder
    %instantaneous touch features
     it = instantTouchBuilder(behavioralStruct,wfa,whiskDir,touchOrder);
    %during touch features
     dt = duringTouchBuilder(behavioralStruct,wfa,whiskDir,touchOrder);
    
    %% Plotting of instantaneous and during touch features
    %can set 'yOut' to build feature distribution based on 'ttype' or 'choice'
%     featurePlotter(it,dt,outcomes,yOut)
    
    %% Design matrix construction
    [DmatXIT, DmatXDT, tnums, fieldsList] = designMatrixBuilder(it,dt,Xhow);

    DmatX = [DmatXIT DmatXDT];

    DmatX = DmatX(:,DmatSelect);
    fieldsList = fieldsList(DmatSelect);

    % Dmat Y builder
    if strcmp(Xhow,'mean')
        if strcmp(yOut,'ttype')
            DmatY = (outcomes.matrix(1,:)==1)';
        elseif strcmp(yOut,'choice')
            DmatY = (outcomes.matrix(3,:)==1)';
        elseif strcmp(yOut,'discrete')
            DmatY = (outcomes.matrix(6,:))';
        end
        missY = outcomes.matrix(5,:) == -1;
    elseif strcmp(Xhow,'individual')
        if strcmp(yOut,'ttype')
            tmpY = (outcomes.matrix(1,:)==1)';
        elseif strcmp(yOut,'choice')
            tmpY = (outcomes.matrix(3,:)==1)';
        elseif strcmp(yOut,'discrete')
            tmpY = (outcomes.matrix(6,:))';
        end
        misstmp = outcomes.matrix(5,:) == -1;
        missY = misstmp(tnums);
        DmatY = tmpY(tnums); 
    else
        error('need to define "Xhow" as "mean" or "individual"') 
    end
        
    
    %removing nan(non-touch) values and miss
    missTrials = find(missY == 1)';
    [rowsNAN, ~] = find(isnan(DmatX));
    [rowsINF, ~] = find(isinf(DmatX));
    DmatY(unique([rowsNAN ; rowsINF ; missTrials]),:)=[];
    DmatX(unique([rowsNAN ; rowsINF ; missTrials]),:)=[];
    
    if strcmp(Xhow,'mean')
    outcomes.matrix(7,unique([rowsNAN ; rowsINF ; missTrials])) = 0; %indexing non-touch and miss trials
    end
    
    %standardization
    DmatX = (DmatX-mean(DmatX))./std(DmatX);
    %% Model running
    mdl.fitCoeffsFields = fieldsList;
    mdl.io.X = DmatX;
    mdl.io.Y = DmatY; 
    mdl.it = it;
    mdl.dt = dt; 
    mdl.outcomes = outcomes; 
    
    if numel(unique(DmatY))==2 % BINOMIAL GLM MODEL 
        mdl = binomialModel(mdl,DmatX,DmatY,glmnetOpt);
        mdl.logDist = 'binomial';
        groupMdl{d} = mdl;
        
    else % MULTINOMIAL GLM MODEL 
        mdl = multinomialModel(mdl,DmatX,DmatY,glmnetOpt);
        mdl.logDist = 'multinomial';
        groupMdl{d} = mdl;

    end
    
    save([saveDir mdlName],'groupMdl')
end


