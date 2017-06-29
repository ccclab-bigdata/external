function [BPM, error, H] = wfu_bpm_setup
%----------------------------------------------%
%                  BPM GUI                     %
%----------------------------------------------%

H = spm('FnUIsetup','WFU BPM Analysis',0);
error = 0;

%----- Result directory ---------%
if exist('spm_get')
    BPM.result_dir  = spm_str_manip(spm_get(-1,'*','Results directory',pwd),'r');
else
    BPM.result_dir  = spm_str_manip(spm_select(1, 'dir', 'Results directory', [], pwd), '.*');
end
wdir = BPM.result_dir ;
disp(['Results directory:  ' wdir]);
cd(wdir);

%----- analysis type -----%
BPM.type = spm_input('Select type of analysis','1','m', ...
    'Anova|Ancova|Ancova ROI|Correlation Analyses|Regression', ...
       ['ANOVA      ' ; ...
        'ANCOVA     '; ...
        'ANCOVA_ROI '; ...
        'CORR-ANAL  '; ...      
        'REGRESSION ']);
swd = pwd;
if strcmp(BPM.type,'CORR-ANAL')
    BPM.type = spm_input('Select type of Correlation Analysis','1','m', ...
        'Correlation|Partial Correlation', ...
        ['CORR       ' ; ...         
         'PCORR      ']);
end

BPM.robust = 0;
BPM.rwfun = [];
BPM.pMaxOut = 1;
% -------- generating the master file ------------%
switch BPM.type
    case {'CORR'}
        [flist{1}{1}, swd] = wfu_bpm_get_any_file(sprintf('First file list for %s',  BPM.type), swd);
        [flist{2}{1}, swd] = wfu_bpm_get_any_file(sprintf('Second file list for %s', BPM.type), swd);       
        fname = wfu_bpm_write_flist_gen(wdir,flist,2);
        BPM.flist = fname  ;
        BPM.corr_type = spm_input('Select type of Correlation','1','m', ...
            'Voxel-Voxel|Voxel-ROI', ...
            ['V-V  ' ; ...                        
             'V-ROI']);
        if strcmp(BPM.corr_type,'V-ROI')          
            %   ---------- Enter the mask ----------------%
            [BPM.mask_ROI, swd]  = wfu_bpm_get_image_file('Select ROI mask', swd);
        end
    case {'PCORR'}
        [flist{1}{1}, swd] = wfu_bpm_get_any_file(sprintf('First file list for %s',  BPM.type), swd);
        [flist{2}{1}, swd] = wfu_bpm_get_any_file(sprintf('Second file list for %s', BPM.type), swd);       
        fname = wfu_bpm_write_flist_gen(wdir,flist,2);
        BPM.flist = fname  ;
        [BPM.pc_control_var, swd] = wfu_bpm_get_any_file(sprintf(' select the control variables file for %s', BPM.type), swd);
        BPM.corr_type = '';

    case {'ANCOVA'}  
        nGroups= spm_input('How many groups? ','+1', 'n1', '2');        
        for k = 1:nGroups
            [flist{1}{k}, swd, defStr] = wfu_bpm_get_any_file(sprintf('Main group %d file list', k), swd);              
            title_group{1}{k}  = spm_input(sprintf('Name of data group (%i of %i) ',k,nGroups),'+1','s',defStr);
        end
        
        nModalities = spm_input('How many imaging covariates? ','+1');
        for cv = 1:nModalities
            title_img_cov{cv} = spm_input(sprintf('Name of imaging covariate #%d ',cv),'+1','s');
        end
        
        % ----- Case of imaging covariates --------%
        if nModalities > 0
            for m = 2:nModalities+1
                for k = 1:nGroups
                    [flist{m}{k}, swd, defStr] = wfu_bpm_get_any_file(sprintf('Modality %d group %d file list ', m, k), swd);              
                    title_group{m}{k}  = spm_input(sprintf('Name of covariate for %s ',title_group{1}{k}),'+1','s',defStr);
                end       
            end
            BPM.flist = wfu_bpm_write_flist_gen(wdir,flist,nModalities+1);
            
        end
        niCov = spm_input('Any non-imaging covariates? ','+1','y/n',[1,0],2);
        
        % No regressors ---> error
        if (nModalities == 0) & (niCov == 0)
            display('Ancova requires at least one covariate')
            error = 1;
            return
        end
        
        %-------- No imaging covariates case ------------%
        if (nModalities == 0) & (niCov > 0)            
           fname = wfu_bpm_write_flist_gen(wdir,flist,1);
            BPM.flist = fname  ;                
        end
        
        % ------- Loading non-imaging covariate data ----%
        if niCov > 0
            [BPM.conf, swd] = wfu_bpm_get_any_file(sprintf('Non-imaging covariates file for %s', BPM.type), swd);
            col_cof = load(BPM.conf);
            nIC = size(col_cof,2);
            for cv = 1:nIC
                title_ni_cov{cv} = spm_input(sprintf('Name of nonimaging covariate#%d ',cv),'+1','s');
            end
        else
            BPM.conf = [];
        end
        
        % ------ choose robust or nonrobust regression -----%
        if spm_input(['Use Robust ' BPM.type '? '],'+1','y/n',[1,0],0)
            BPM.robust = 1;
            BPM.rwfun = spm_input('Select weight function','+1','m', ...
                    'Andrews|Bisquare|Cauchy|Fair|Huber|Logistic|Talwar|Welsch', ...
                       ['andrews ' ; ...
                        'bisquare'; ...
                        'cauchy  '; ...
                        'fair    '; ...      
                        'huber   ';...
                        'logistic';...
                        'talwar  ';...
                        'welsch  ']);
                    
            BPM.pMaxOut = spm_input('Proportional Maximum Outliers','+1','e',0.2);

        end
        
    case 'ANCOVA_ROI'
        
        nGroups= spm_input('How many groups? ','+2', 'n1', '2');        
        for k = 1:nGroups
            [flist{1}{k}, swd, defStr] = wfu_bpm_get_any_file(sprintf('Main group %d file list', k), swd);              
            title_group{1}{k}  = spm_input(sprintf('Name of data group (%i of %i) ',k,nGroups),'+1','s',defStr);
        end       
                
        nModalities = 1;
        for cv = 1:nModalities
            title_img_cov{cv} = spm_input(sprintf('Name of the ROI regressor %d',cv),'+1','s');
        end
        
        % ----- Case of imaging covariates --------%
        for m = 2:nModalities+1
            for k = 1:nGroups
                [flist{m}{k}, swd, defStr] = wfu_bpm_get_any_file(sprintf('Modality %d group %d file list ', m, k), swd);              
                title_group{m}{k}  = spm_input(sprintf('Name of covariate for %s ',title_group{1}{k}),'+1','s',defStr);
            end   
        end
        
        BPM.flist = wfu_bpm_write_flist_gen(wdir,flist,nModalities+1);        
                
        %   ---------- Enter the mask ----------------%
        
        [BPM.mask_ancova_ROI, swd]  = wfu_bpm_get_image_file('Select ROI mask', swd);        
        niCov = spm_input('Any non-imaging covariates? ','+1','y/n',[1,0],2);        
                
        % ------- Loading non-imaging covariate data ----%
        if niCov > 0
            [BPM.conf, swd] = wfu_bpm_get_any_file(sprintf('Non-imaging covariates file for %s', BPM.type), swd);
            col_cof = load(BPM.conf);
            nIC = size(col_cof,2);
            for cv = 1:nIC
                title_ni_cov{cv} = spm_input(sprintf('Name of nonimaging covariate#%d ',cv),'+1','s');
            end
        else
            BPM.conf = [];
        end    
        

    case {'ANOVA'}         
        nModalities = 1;
        nGroups = spm_input('How many groups? ','+2', 'n1', '2');
        for k = 1:nGroups
            [flist{nModalities}{k}, swd, defStr] = wfu_bpm_get_any_file(sprintf('Group %d file list ',  k), swd);              
            title_group{1}{k}  = spm_input(sprintf('Name of data group (%i of %i) ',k,nGroups),'+1','s',defStr);
        end
      
        fname = wfu_bpm_write_flist_gen(wdir,flist,nModalities);
        BPM.flist = fname  ;      
        BPM.conf = [];
    case {'REGRESSION'}       

        BPM.type = 'REGRESSION';
        
        [flist{1}{1}, swd] = wfu_bpm_get_any_file(sprintf('Dependent modality file list for %s',  BPM.type), swd);
        title_group{1}{1}  = spm_input('Name of the main modality ','+2','s');
        
        nModalities = spm_input('How many imaging covariates? ','+1');
        for cv = 1:nModalities
            title_img_cov{cv} = spm_input(sprintf('Name of imaging covariate#%d ',cv),'+1','s');
        end
       
        for m = 2:nModalities+1                
            [flist{m}{1}, swd] = wfu_bpm_get_any_file(sprintf('Modality %d file list ', m), swd);                                     
        end
        
        BPM.flist = wfu_bpm_write_flist_gen(wdir,flist,nModalities+1);
         
        niCov = spm_input('Any non-imaging covariates? ','+1','y/n',[1,0],2);
        
        % ----- No regressors error ---------------------%
        if (nModalities == 0) & (niCov == 0)
            display('Regression requires at least one covariate')
            error = 1;
            return
        end
        
        % --- Selecting the file with non-imaging covariates information--%       
        
        if niCov > 0
            [BPM.conf, swd] = wfu_bpm_get_any_file(sprintf('Non-imaging covariates file for %s', BPM.type), swd);
            col_cof = load(BPM.conf);
            nIC = size(col_cof,2);
            for cv = 1:nIC
                title_ni_cov{cv} = spm_input(sprintf('Name of non-imaging covariates#%d ',cv),'+1','s');
            end
        else
            BPM.conf = [];
        end
        nGroups = 1;

        if spm_input(['Use Robust ' BPM.type '? '],'+1','y/n',[1,0],0)
            BPM.robust = 1;
            BPM.rwfun = spm_input('Select weight function','+1','m', ...
                    'Andrews|Bisquare|Cauchy|Fair|Huber|Logistic|Talwar|Welsch', ...
                       ['andrews ' ; ...
                        'bisquare'; ...
                        'cauchy  '; ...
                        'fair    '; ...      
                        'huber   ';...
                        'logistic';...
                        'talwar  ';...
                        'welsch  ']);
           BPM.pMaxOut = spm_input('Proportional Maximun Outliers','+1','e',0.2);

        end
end

%----- brain mask -----% 
if spm_input('Apply a predefined brain mask? ','+1','y/n',[1 0],0)
 %   ---------- Enter the mask ----------------%
    [BPM.mask, swd]  = wfu_bpm_get_image_file('Select mask', swd);
    
else
    tt = spm_input('Threshold type', '+1', 'Proportional|Absolute',[],1);
    if strcmp(tt, 'Proportional')
        Pthr = spm_input('threshold ','+1','e',0.1);   
        BPM.mask_pthr = Pthr ;
    else
        Athr = spm_input('threshold ','+1','e',0.1);   
        BPM.mask_athr = Athr ;
    end
    BPM.mask       = ''   ;
end

if ~(strcmp(BPM.type,'CORR') | strcmp(BPM.type,'REGRESSION') | strcmp(BPM.type,'PCORR') )
    BPM.DMS(1) = nGroups;
    % Add mean as part of titles
    for k = 1:BPM.DMS(1)
        BPM.titles{k} = title_group{1}{k};
    end
else
    BPM.DMS(1) = 1;
    % Add mean as the first title
    BPM.titles{1} = 'mean'; 
end


% 
if (strcmp(BPM.type,'ANCOVA') | strcmp(BPM.type,'REGRESSION')|strcmp(BPM.type,'ANCOVA_ROI'))
    if niCov > 0
        BPM.DMS(2) = size(col_cof,2);
        
        for k = 1:BPM.DMS(2)
            BPM.titles{k+BPM.DMS(1)} = title_ni_cov{k};
        end
    else
        BPM.DMS(2) = 0;
    end
    if nModalities > 0
        BPM.DMS(3) = nModalities;
        for k = 1:BPM.DMS(3)
            BPM.titles{k+BPM.DMS(1)+BPM.DMS(2)} = title_img_cov{k};
        end
    else
        BPM.DMS(3) = 0;
    end
end

function [fileh, swd, name] = wfu_bpm_get_any_file(title, dir)
if exist('spm_get')
    fileh = spm_get(1, '*', title);
else
    fileh = spm_select(1, 'any', title, [], dir, '.*');
end
[swd, name] = fileparts(fileh);

function [fileh, swd, name] = wfu_bpm_get_image_file(title, dir)
if exist('spm_get')
    fileh = spm_get(1, '*.img', title);
else
    fileh = spm_select(1, 'IMAGE', title, [], dir, '.*');
end
[swd, name] = fileparts(fileh);
