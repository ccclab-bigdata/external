function spm_surfrend

% function spm_surfrend
%
% SPM toolbox function wrapper. Provide interactive user interface for
% the SPM surfrend toolbox. 
%
% The following options ar available:
% 1. Create w-file overlay from SPM Canonical brain
%    -- overlay is generated for the colin27 anatomy (SPM single_subj_T1{img,hdr|mn})
%
% 2. Create w-file overlay from FreeSurfer custom surface
%    -- overlay is generated for a user derived surface (e.g.,
%       representative subject's brain)
%
%_______________________________________________________________________
% @(#)spm_surfrend.m	V1.0 CVS $Author: itamarkahn $ $Date: 2008/01/29 21:19:29 $ $Name:  $ $RCSfile: spm_surfrend.m,v $ $Revision: 1.7 $

SPMid = spm('FnBanner',mfilename,'0.2.1');
[Finter,Fgraph,CmdLine] = spm('FnUIsetup','surfrend');
spm_help('!ContextHelp',mfilename);

fig = spm_figure('GetWin','Interactive');
h0  = uimenu(fig,...
	'Label',	'surfrend',...
	'Separator',	'on',...
	'Tag',		'Def',...
	'HandleVisibility','on');
h1  = uimenu(h0,...
	'Label',	'Create w-file overlay from SPM Canonical brain',...
	'Separator',	'off',...
	'Tag',		'Def',...
	'CallBack',	'surfrend_canonical;',...
	'HandleVisibility','on');
h2  = uimenu(h0,...
	'Label',	'Create w-file overlay from FreeSurfer custom surface',...
	'Separator',	'off',...
	'Tag',		'Def',...
	'CallBack',	'surfrend_fscustom;',...
	'HandleVisibility','on');

