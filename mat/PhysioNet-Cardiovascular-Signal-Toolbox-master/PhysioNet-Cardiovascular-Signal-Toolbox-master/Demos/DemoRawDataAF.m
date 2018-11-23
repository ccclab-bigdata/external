%	OVERVIEW:
%       This demonstration analyzes a segment of 5-minutes 'raw' data  
%       with known atrial fibrillation to show the operation of the 
%       AF detection algorithm.
%   OUTPUT:
%       HRV Metrics exported to .cvs files
%
%   DEPENDENCIES & LIBRARIES:
%       https://github.com/cliffordlab/PhysioNet-Cardiovascular-Signal-Toolbox
%   REFERENCE: 
%       Vest et al. "An Open Source Benchmarked HRV Toolbox for Cardiovascular 
%       Waveform and Interval Analysis" Physiological Measurement (In Press), 2018. 
%	REPO:       
%       https://github.com/cliffordlab/PhysioNet-Cardiovascular-Signal-Toolbox
%   ORIGINAL SOURCE AND AUTHORS:     
%       Giulia Da Poian   
%	COPYRIGHT (C) 2018 
%   LICENSE:    
%       This software is offered freely and without warranty under 
%       the GNU (v3 or later) public license. See license file for
%       more information
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; clc; close all;

run(['..' filesep 'startup.m'])

% Remove old files generated by this demo
OldFolder = [pwd,filesep, 'OutputData', filesep, 'ResultsAFData'];
if exist(OldFolder, 'dir')
    rmdir(OldFolder, 's');
    fprintf('Old Demo Folder deleted \n');
end


HRVparams = InitializeHRVparams('demoAF'); % include the project name
HRVparams.poincare.on   = 0; % Poincare analysis off for this demo
HRVparams.DFA.on        = 0; % DFA analysis off for this demo
HRVparams.MSE.on        = 0; % MSE analysis off for this demo
HRVparams.HRT.on        = 0; % HRT analysis off for this demo


[subjectIDs,filesTBA] = GenerateListOfFilesTBA(HRVparams.ext,...
                                                    HRVparams.readdata,0);
idx = find(strcmp(subjectIDs,'TestAFdata'));
i_patient = idx;

% 1. Load Raw Patient Data

load(filesTBA{i_patient});
% 2. Analyze data using HRV PhysioNet Cardiovascular Signal Toolbox
[results, resFilename] = Main_HRV_Analysis(signal(:,1),[],'ECGWaveform',...
                                          HRVparams,subjectIDs(i_patient));


% 3. Compare generated output file with the reference one
        
currentFile = strcat(HRVparams.writedata, filesep, resFilename.HRV, '.csv');
referenceFile = strcat('ReferenceOutput', filesep, 'AFDemo.csv');
testHRV = CompareOutput(currentFile,referenceFile);

% 3. Load QRS annotation saved by Main_HRV_Analysis
annotName = strcat(HRVparams.writedata, filesep, 'Annotation',filesep,...
                                                    subjectIDs(i_patient));
jqrs_ann = read_ann( annotName{1} , 'jqrs');
wqrs_ann = read_ann( annotName{1} , 'wqrs');

% For demo pourpose recompute bsqi
[sqijw, StartIdxSQIwindows] = bsqi(jqrs_ann,wqrs_ann,HRVparams);

HRVparams.gen_figs = 1;
% Plot detected beats
if HRVparams.gen_figs
    Plot_SignalDetection_SQI(time, signal(:,1), jqrs_ann, sqijw,'ECG')
end


if testHRV 
    fprintf('** DemoRawDataAF: TEST SUCCEEDED ** \n ')
    fprintf('A file named %s.csv \n has been saved in %s \n', ...
    resFilename.HRV, HRVparams.writedata);
else
    fprintf('** DemoRawDataAF: TEST FAILED ** \n')
end


