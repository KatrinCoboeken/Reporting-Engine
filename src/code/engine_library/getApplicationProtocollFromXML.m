function [ApplicationProtocol,isValid] = getApplicationProtocollFromXML(Settings,xml,parPathsStudyDesign,parValuesStudyDesign)
% GETAPPLICATIONPROTOCOLLFROMXML get properties of the applicationsprotocol
%       defined within an exported simulationfile (.xml)
%
% Inputs:
%       Settings (structure)    definition of properties used in all
%                   workflow functions see GETDEFAULTWORKFLOWSETTINGS
%   xml (string) name of xmlfile
%   parPathsStudyDesign (cellarray of strings) optional, list of studedsign parameters
%   parValuesStudyDesign (double matrix) optional, values of studedsign parameters
% 
% Outputs;
%   ApplicationProtocol structure with following fields
%       name                (string)    name of application
%       startTime           (double)    [min] starting time of application
%       dose                (double)    [kg]  applicated drug amount
%       dosePerBodyWeight   (double)    [kg/kg] applicated drug amount per body weight
%       drugMass            (double)    [�mol] applicated drug amount
%       isDosePerBodyweight (boolean)   if true, dose is adjusted to bodyweight
%                                       false dose is absolute  
%       infusionTime        (double)    [min] time of infusion, 
%                                       zero if the application is no infusion
%  isValid  (boolean)  if true,  all necessary field were available in the xml file, 
%                      if false, some fields could not be found, may be the xml is a 
%                       MoBi file with a user defined application. Special attention is needed 


% Open Systems Pharmacology Suite;  http://forum.open-systems-pharmacology.org
% Date: 14-July-2017


% initialize return parameter
isValid = true;
ApplicationProtocol = getDefaultApplicationProtocol('');




% initialize simulation file
initSimulation(xml,'none');
simulationIndex=1;

% get list of paths added by studydesign
if exist('parPathsStudyDesign','var') && ~isempty(parPathsStudyDesign)
    studyDesignPathId = cell(length(parPathsStudyDesign),1);
    for iPar = 1:length(parPathsStudyDesign)
        studyDesignPathId{iPar} = getParameter(['*' parPathsStudyDesign{iPar}],simulationIndex,'parametertype','readonly','property','Path');
    end
else
    studyDesignPathId = {};
    parValuesStudyDesign = [];
end

% select application parameter 
[ise,desc] = existsParameter(sprintf('*Application_*|ProtocolSchemaItem|Start time'),simulationIndex,'parametertype','readonly');
if ise
    isIndividualized = false;
    for iApp = 1:size(desc,1)-1
        
        tmp = regexp(desc{iApp+1,2},'\|','split');
        pathPrefix = strjoin(tmp(1:end-1),'|');
        
        % initialize
        ApplicationProtocol(iApp) = getDefaultApplicationProtocol( strjoin(tmp(3:(end-2)),'|')); %#ok<COLND>
        
        % get the relevant Parameter
        [ApplicationProtocol(iApp),isValid,isIndividualized] = addParameter(Settings,ApplicationProtocol(iApp),[pathPrefix,'|Start time'],...
            'startTime',simulationIndex,studyDesignPathId,parValuesStudyDesign,isValid,isIndividualized);
        [ApplicationProtocol(iApp),isValid,isIndividualized] = addParameter(Settings,ApplicationProtocol(iApp),[pathPrefix,'|Dose'],...
            'dose',simulationIndex,studyDesignPathId,parValuesStudyDesign,isValid,isIndividualized);
        [ApplicationProtocol(iApp),isValid,isIndividualized] = addParameter(Settings,ApplicationProtocol(iApp),[pathPrefix,'|DosePerBodyWeight'],...
            'dosePerBodyWeight',simulationIndex,studyDesignPathId,parValuesStudyDesign,isValid,isIndividualized);
        
        % drugmass may overwrite formulacheck of dose, call it after the dose call
        [ApplicationProtocol(iApp),isValid,isIndividualized] = addParameter(Settings,ApplicationProtocol(iApp),[pathPrefix,'|DrugMass'],...
            'drugMass',simulationIndex,studyDesignPathId,parValuesStudyDesign,isValid,isIndividualized);
        
        [ApplicationProtocol(iApp),isValid,isIndividualized] = addParameter(Settings,ApplicationProtocol(iApp),[pathPrefix,'|Infusion time'],...
            'infusionTime',simulationIndex,studyDesignPathId,parValuesStudyDesign,isValid,isIndividualized);
        
    end
else
    writeToLog('There is no valid application within the xml',Settings.logfile,true,false);
    isValid = false;
end    

if ~isValid
    return
end

% take only application within simulation range
simulationTime = getSimulationTime(simulationIndex);
jj = [ApplicationProtocol.startTime] < simulationTime(end);
ApplicationProtocol = ApplicationProtocol(jj);

% take only application with a Drugmass > 0
jj = any([ApplicationProtocol.drugMass] > 0,1);
ApplicationProtocol = ApplicationProtocol(jj);

% check if there is a application protocol
if isempty(ApplicationProtocol)
    writeToLog('There is no valid application within the xml',Settings.logfile,true,false);
    isValid = false;
    return
end


% list application protocol in logfile
writeToLog(sprintf('Applicationprotocol'),Settings.logfile,true,false);
for iApp = 1:length(ApplicationProtocol)
    
    if isIndividualized
        dosetxt = sprintf('individualized dose'); 
    else
        if ApplicationProtocol(iApp).isDosePerBodyweight
            dosetxt = sprintf('dose %g g/kg',ApplicationProtocol(iApp).dosePerBodyWeight*1e6);
        else
            dosetxt = sprintf('dose %g g',ApplicationProtocol(iApp).dose*1e6);
        end
    end
    
    msg = sprintf('  %s: start time %g min; %s; infusion time %g min',ApplicationProtocol(iApp).name,ApplicationProtocol(iApp).startTime,...
        dosetxt,ApplicationProtocol(iApp).infusionTime);
    writeToLog(msg,Settings.logfile,true,false);
end

return


function ApplicationProtocol = getDefaultApplicationProtocol(name)

 ApplicationProtocol =    struct('name',name,'startTime',nan,...
        'dose',nan,'dosePerBodyWeight',nan,'drugMass',nan,'isDosePerBodyweight',false,...
        'infusionTime',0);
    
return    
    
 function [ApplicationProtocol,isValid,isIndividualized] = addParameter(Settings,ApplicationProtocol,pathID,...
         fieldNameStructure,simulationIndex,studyDesignPathId,parValuesStudyDesign,isValid,isIndividualized)
         
if existsParameter(pathID,simulationIndex,'parametertype','readonly');
    ApplicationProtocol.(fieldNameStructure) = getParameter(pathID,simulationIndex,'parametertype','readonly');

    % check formulas
    switch fieldNameStructure
        case 'dose'
            ApplicationProtocol.isDosePerBodyweight = ...
                getParameter(pathID,simulationIndex,'parametertype','readonly','property','isFormula');
    end

    
    % check if pathID is part of studyDesign
    if ~isempty(studyDesignPathId)
        pathID = getParameter(pathID,simulationIndex,'parametertype','readonly','property','Path');
        for iPar = 1:length(studyDesignPathId)
            jj = ismember(pathID,studyDesignPathId{iPar});
            if any(jj)
                isIndividualized = true;
                ApplicationProtocol.(fieldNameStructure) = parValuesStudyDesign(:,iPar);
        
                switch fieldNameStructure
                    case 'startTime'
                        writeToLog('startTime is individualized by study design, applicationprotocol of xml is set to invalid',Settings.logfile,true,false);
                        isValid = false;
                    case 'drugMass'
                        % if drugmass is set individualized, dose ist absolute
                        ApplicationProtocol.isDosePerBodyweight = false;
                end
            end
        end
                
    end
else
    % check if mandatory field are missing
    switch fieldNameStructure
        case {'startTime','dose','dosePerBodyWeight','drugMass'}
                writeToLog(sprintf('mandatory field %s is missing, applicationprotocol of xml is set to invalid',fieldNameStructure),...
                    Settings.logfile,true,false);
                isValid = false;
    end
            
end


return    
    