function varargout = wfu_spm_list99(varargin)
% Display and analysis of SPM{.}
% FORMAT TabDat = wfu_spm_list99('List',       SPM,VOL,Dis,Num,Title,hReg)
% Summary list of local maxima for entire volume of interest
% FORMAT TabDat = wfu_spm_list99('ListCluster',SPM,VOL,Dis,Num,Title,hReg)
% List of local maxima for a single suprathreshold cluster
%
% SPM    - structure containing SPM, distribution & filtering details
%        - required fields are:
% .swd   - SPM working directory - directory containing current SPM.mat
% .Z     - minimum of n Statistics {filtered on u and k}
% .n     - number of conjoint tests        
% .STAT  - distribution {Z, T, X or F}     
% .df    - degrees of freedom [df{interest}, df{residual}]
% .u     - height threshold
% .k     - extent threshold {voxels}
% .XYZ   - location of voxels {voxel coords}
% .XYZmm - location of voxels {mm}
%
% VOL    - structure containing details of volume analysed
%        - required fields are:
% .S     - search Volume {voxels}
% .R     - search Volume {resels}
% .FWHM  - smoothness {voxels}     
% .M     - voxels - > mm matrix
% .VOX   - voxel dimensions {mm}
%
% (see spm_getSPM for further details of SPM & VOL structures)
%
% Dis    - Minimum distance between maxima
%          {defaults (missing or empty) to 8mm for 'List', 4mm for 'ListCluster'}
% Num    - Maxiumum number of local maxima tabulated per cluster
%          {defaults (missing or empty) to 3   for 'List', Inf for 'ListCluster'}
% Title  - Title text for table {defaults on missing or empty}
% hReg   - Handle of results section XYZ registry (see spm_results_ui.m)
%
% TabDat - Structure containing table data
%        - fields are
% .tit   - table Title (string)
% .hdr   - table header (2x10 cell array)
% .fmt   - fprintf format strings for table data (1x10 cell array)
% .str   - table filtering note (string)
% .ftr   - table footnote information (4x2 cell array)
% .dat   - table data (Nx10 cell array)
%
%                           ----------------
%
% FORMAT wfu_spm_list99('TxtList',TabDat,c)
% Prints a tab-delimited text version of the table
% TabDat - Structure containing table data (format as above)
% c      - Column of table data to start text table at
%          (E.g. c=3 doesn't print set-level results contained in columns 1 & 2)
%                           ----------------
%
% FORMAT wfu_spm_list99('SetCoords',xyz,hAx,hC)
% Highlighting of table co-ordinates (used by results section registry)
% xyz    - 3-vector of new co-ordinate
% hAx    - table axis (the registry object for tables)
% hReg   - Handle of caller (not used)
%_______________________________________________________________________
%
% wfu_spm_list99 characterizes SPMs (thresholded at u and k) in terms of
% excursion sets (a collection of face, edge and vertex connected
% subsets or clusters).  The currected significance of the results are
% based on set, cluster and voxel-level inferences using distributional
% approximations from the Theory of Gaussian Feilds.  These
% distributions assume that the SPM is a reasonable lattice
% approximation of a continuous random field with known component field
% smoothness.
%
% The p values are based on the probability of obtaining c, or more,
% clusters of k, or more, resels above u, in the volume S analysed =
% P(u,k,c).  For specified thresholds u, k, the set-level inference is
% based on the observed number of clusters C, = P(u,k,C).  For each
% cluster of size K the cluster-level inference is based on P(u,K,1)
% and for each voxel (or selected maxima) of height U, in that cluster,
% the voxel-level inference is based on P(U,0,1).  All three levels of
% inference are supported with a tabular presentation of the p values
% and the underlying statistic:
%
% Set-level     - c    = number of suprathreshold clusters
%               - P    = prob(c or more clusters in the search volume)
%
% Cluster-level - k    = number of voxels in this cluster
%               - Pc   = prob(k or more voxels in the search volume)
%               - Pu   = prob(k or more voxels in a cluster)
%
% Voxel-level   - T/F  = Statistic upon which the SPM is based
%               - Ze   = The eqivalent Z score - prob(Z > Ze) = prob(t > T)
%               - Pc   = prob(Ze or higher in the search volume)
%               - Pu   = prob(Ze or higher at that voxel)
%
% x,y,z (mm)    - Coordinates of the voxel
%
% The table is grouped by regions and sorted on the Ze-variate of the
% primary maxima.  Ze-variates (based on the uncorrected p value) are the
% Z score equivalent of the statistic. Volumes are expressed in voxels.
%
% Clicking on values in the table returns the value to the Matlab
% workspace. In addition, clicking on the co-ordinates jumps the
% results section cursor to that location. The table has a context menu
% (obtained by right-clicking in the background of the table),
% providing options to print the current table as a text table, or to
% extract the table data to the Matlab workspace.
%
%_______________________________________________________________________
% @(#)spm_list.m	2.34 Karl Friston, Andrew Holmes 01/06/23


%-Parse arguments, default to 'list' if varargin{1} not an Action string
%-----------------------------------------------------------------------
if nargin==0, error('Insufficient arguments'), end
if ~ischar(varargin{1})
	warning('Direct usage Grandfathered: Use an action string!')
	wfu_spm_list99('list',varargin{:});
	return
end



%=======================================================================
switch lower(varargin{1}), case 'list'                            %-List
%=======================================================================
% FORMAT TabDat = wfu_spm_list99('list',SPM,VOL,Dis,Num,Title,hReg)


%-Tolerance for p-value underflow, when computing equivalent Z's
%-----------------------------------------------------------------------
tol = eps*10;

%-Parse arguments
%-----------------------------------------------------------------------
if nargin<3,     error('insufficient arguments'), end
if nargin<7,	 hReg=[]; else, hReg = varargin{7}; end
if nargin<6,     Title = '';
	else,    Title = varargin{6}; end
if isempty(Title), Title = ['volume summary',...
			' (p-values corrected for entire volume)']; end
if nargin<5,     Num = [];
	else,    Num = varargin{5}; end
if isempty(Num), Num = 03; end
if nargin<4,     Dis = [];
	else,    Dis = varargin{4}; end
if isempty(Dis), Dis = 08; end
% VOL is varargin{3} - Use by reference for speed
% SPM is varargin{2} - Don't copy into local variables

%-Get current location (to highlight selected voxel in table)
%-----------------------------------------------------------------------
xyzmm = spm_results_ui('GetCoords');

%-Extract data from structures
%-----------------------------------------------------------------------
S         = varargin{3}.S;
R         = varargin{3}.R;
FWHM      = varargin{3}.FWHM;
v2r       = 1/prod(FWHM(~isinf(FWHM)));			%-voxels to resels
n         = varargin{2}.n;
STAT      = varargin{2}.STAT;
df        = varargin{2}.df;
u         = varargin{2}.u;
k         = varargin{2}.k*v2r;

%-Setup graphics pane
%-----------------------------------------------------------------------
spm('Pointer','Watch')
Fgraph    = spm_figure('GetWin','Graphics');
spm_results_ui('Clear',Fgraph)
FS        = spm('FontSizes');			%-Scaled font sizes
PF        = spm_platform('fonts');		%-Font names (for this platform)




%-Table header & footer
%=======================================================================

%-Table axes & Title
%-----------------------------------------------------------------------
hAx   = axes('Position',[0.05 0.1 0.9 0.4],...
	'DefaultTextFontSize',FS(8),...
	'DefaultTextInterpreter','Tex',...
	'DefaultTextVerticalAlignment','Baseline',...
	'Units','points',...
	'Visible','off');
AxPos = get(hAx,'Position'); set(hAx,'YLim',[0,AxPos(4)])
dy    = FS(9);
y     = floor(AxPos(4)) - dy;

text(0,y,['Statistics:  \it\fontsize{',num2str(FS(9)),'}',Title],...
	'FontSize',FS(11),'FontWeight','Bold');	y = y - dy/2;
line([0 1],[y y],'LineWidth',3,'Color','r'),	y = y - 9*dy/8;


%-Construct table header
%-----------------------------------------------------------------------
set(gca,'DefaultTextFontName',PF.helvetica,'DefaultTextFontSize',FS(8))

Hc = [];
h = text(0.01,y,	'set-level','FontSize',FS(9));		Hc = [Hc,h];
h=line([0.00,0.11],[y-dy/4,y-dy/4],'LineWidth',0.5,'Color','r');Hc = [Hc,h];
h = text(0.02,y-9*dy/8,	'\itp ');				Hc = [Hc,h];
h = text(0.09,y-9*dy/8,	'\itc ');				Hc = [Hc,h];

text(0.22,y,		'cluster-level','FontSize',FS(9))
line([0.16,0.42],[y-dy/4,y-dy/4],'LineWidth',0.5,'Color','r')
text(0.16,y-9*dy/8,	'\itp \rm_{corrected}')
text(0.28,y-9*dy/8,	'\itk \rm_E')
text(0.33,y-9*dy/8,	'\itp \rm_{uncorrected}')

text(0.60,y,		'voxel-level','FontSize',FS(9))
line([0.48,0.83],[y-dy/4,y-dy/4],'LineWidth',0.5,'Color','r')
text(0.48,y-9*dy/8,	'\itp \rm_{corrected}')
text(0.60,y-9*dy/8,	sprintf('\\it%c',STAT))
text(0.68,y-9*dy/8,	'(\itZ\rm_\equiv)')
text(0.75,y-9*dy/8,	'\itp \rm_{uncorrected}')

text(0.90,y - dy/2,['x,y,z \fontsize{',num2str(FS(8)),'}\{mm\}']);

%-Headers for text table...
TabDat.tit = Title;
TabDat.hdr = {	'set',		'c';...
		'set',		'p';...
		'cluster',	'p(cor)';...
		'cluster',	'equivk';...
		'cluster',	'p(unc)';...
		'voxel',	'p(cor)';...
		'voxel',	STAT;...
		'voxel',	'equivZ';...
		'voxel',	'p(unc)';...
		'',		'x,y,z {mm}'}';
TabDat.fmt = {	'%-0.3f', '%g',...				%-Set
		'%0.3f',  '%0.0f',  '%0.3f',...			%-Cluster
		'%0.3f',  '%6.2f',  '(%5.2f)',  '%0.3f',...	%-Voxel
		'%3.0f %3.0f %3.0f'};				%-XYZ

y     = y - 7*dy/4;
line([0 1],[y y],'LineWidth',1,'Color','r')
y     = y - 5*dy/4;
y0    = y;


%-Table filtering note
%-----------------------------------------------------------------------
if isinf(Num)
	TabDat.str = sprintf('table shows all local maxima > %.1fmm apart',Dis);
else
	TabDat.str = sprintf(['table shows at most %s local maxima ',...
		'> %.1fmm apart per cluster'],Num,Dis);
end
text(0.5,4,TabDat.str,'HorizontalAlignment','Center','FontName',PF.helvetica,...
    'FontSize',FS(8),'FontAngle','Italic')


%-Volume, resels and smoothness 
%-----------------------------------------------------------------------
FWHMmm          = FWHM.*varargin{3}.VOX'; 			% FWHM {mm}
Pz              = spm_P(1,0,u,df,STAT,1,n,S);
Pu              = spm_P(1,0,u,df,STAT,R,n,S);
[P Pn Em En EN] = spm_P(1,k,u,df,STAT,R,n,S);


%-Footnote with SPM parameters
%-----------------------------------------------------------------------
line([0 1],[0 0],'LineWidth',1,'Color','r')
set(gca,'DefaultTextFontName',PF.helvetica,...
	'DefaultTextInterpreter','None','DefaultTextFontSize',FS(8))
TabDat.ftr = cell(4,2);
TabDat.ftr{1} = ...
	sprintf('Height threshold: %c = %0.2f, p = %0.3f (%0.3f corrected)',...
		 STAT,u,Pz,Pu);
TabDat.ftr{2} = ...
sprintf('Extent threshold: k = %0.0f voxels, p = %0.3f (%0.3f corrected)',...
	         k/v2r,Pn,P);
TabDat.ftr{3} = ...
	sprintf('Expected voxels per cluster, <k> = %0.3f',En/v2r);
TabDat.ftr{4} = ...
	sprintf('Expected number of clusters, <c> = %0.2f',Em*Pn);
TabDat.ftr{5} = ...
	sprintf('Degrees of freedom = [%0.1f, %0.1f]',df);
TabDat.ftr{6} = ...
	sprintf(['Smoothness FWHM = %0.1f %0.1f %0.1f {mm} ',...
		 ' = %0.1f %0.1f %0.1f {voxels}'],FWHMmm,FWHM);
TabDat.ftr{7} = ...
	sprintf('Search volume: S = %0.0f mm^3 = %0.0f voxels = %0.1f resels',...
		S*prod(varargin{3}.VOX),S,R(end));
TabDat.ftr{8} = ...
	sprintf(['Voxel size: [%0.1f, %0.1f, %0.1f] mm ',...
		' (1 resel = %0.2f voxels)'],...
		varargin{3}.VOX,prod(FWHM));

text(0.0,-1*dy,TabDat.ftr{1},...
	'UserData',[u,Pz,Pu],'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.0,-2*dy,TabDat.ftr{2},...
	'UserData',[k/v2r,Pn,P],'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.0,-3*dy,TabDat.ftr{3},...
	'UserData',En/v2r,'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.0,-4*dy,TabDat.ftr{4},...
	'UserData',Em*Pn,'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.5,-1*dy,TabDat.ftr{5},...
	'UserData',df,'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.5,-2*dy,TabDat.ftr{6},...
	'UserData',FWHMmm,'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.5,-3*dy,TabDat.ftr{7},...
	'UserData',[S*prod(varargin{3}.VOX),S,R(end)],...
	'ButtonDownFcn','get(gcbo,''UserData'')')
text(0.5,-4*dy,TabDat.ftr{8},...
	'UserData',[varargin{3}.VOX',prod(FWHM)],...
	'ButtonDownFcn','get(gcbo,''UserData'')')




%-Characterize excursion set in terms of maxima
% (sorted on Z values and grouped by regions)
%=======================================================================
if ~length(varargin{2}.Z)
	text(0.5,y-6*dy,'no suprathreshold clusters',...
		'HorizontalAlignment','Center',...
		'FontAngle','Italic','FontWeight','Bold',...
		'FontSize',FS(16),'Color',[1,1,1]*.5);
	TabDat.dat = cell(0,10);
	varargout = {TabDat};
	spm('Pointer','Arrow')
	return
end

% Includes Darren Gitelman's code for working around bug in
% spm_max for conjunctions with negative thresholds
%-----------------------------------------------------------------------
minz = abs(min(min(varargin{2}.Z)));
zscores = 1+minz+varargin{2}.Z;
[N Z XYZ A] = spm_max(zscores,varargin{2}.XYZ);
Z = Z-minz-1;
%-----------------------------------------------------------------------

%-Convert cluster sizes from voxels to resels
%-----------------------------------------------------------------------
if isfield(varargin{3},'VRVP')
	V2R = spm_sample_vol(varargin{3}.VRVP,XYZ(1,:),XYZ(2,:),XYZ(3,:),0);
else
	V2R = v2r;
end
N         = N.*V2R;

%-Convert maxima locations from voxels to mm
%-----------------------------------------------------------------------
XYZmm     = varargin{3}.M(1:3,:)*[XYZ; ones(1,size(XYZ,2))];



%-Table proper (& note all data in cell array)
%=======================================================================

%-Pagination variables
%-----------------------------------------------------------------------
hPage = [];
set(gca,'DefaultTextFontName',PF.courier,'DefaultTextFontSize',FS(7))


%-Set-level p values {c} - do not display if reporting a single cluster
%-----------------------------------------------------------------------
c     = max(A);					%-Number of clusters
Pc    = spm_P(c,k,u,df,STAT,R,n,S);		%-Set-level p-value

if c > 1;
	h     = text(0.00,y,sprintf(TabDat.fmt{1},Pc),'FontWeight','Bold',...
		'UserData',Pc,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
	h     = text(0.08,y,sprintf(TabDat.fmt{2},c),'FontWeight','Bold',...
		'UserData',c,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
else
	set(Hc,'Visible','off')
end

TabDat.dat = {Pc,c};				%-Table data
TabLin     = 1;					%-Table data line


%-Local maxima p-values & statistics
%-----------------------------------------------------------------------
HlistXYZ = [];
while prod(size(find(finite(Z))))

	% Paginate if necessary
	%---------------------------------------------------------------
	if y < min(Num+1,3)*dy
		h     = text(0.5,-5*dy,...
			sprintf('Page %d',spm_figure('#page')),...
			'FontName',PF.helvetica,'FontAngle','Italic',...
			'FontSize',FS(8));
		spm_figure('NewPage',[hPage,h])
		hPage = [];
		y     = y0;
	end

    	%-Find largest remaining local maximum
    	%---------------------------------------------------------------
	[U,i]   = max(Z);			% largest maxima
	j       = find(A == A(i));		% maxima in cluster


    	%-Compute cluster {k} and voxel-level {u} p values for this cluster
    	%---------------------------------------------------------------
	Pz      = spm_P(1,0,   U,df,STAT,1,n,S);% uncorrected p value
	Pu      = spm_P(1,0,   U,df,STAT,R,n,S);% corrected     {based on Z)
	[Pk Pn] = spm_P(1,N(i),u,df,STAT,R,n,S);% [un]corrected {based on k)

	Nv      = N(i)/v2r;			% extent        {voxels}
	if Pz<tol				% Equivalent Z-variate
	    Ze  = Inf;	 			% (underflow => can't compute)
	else
	    Ze  = spm_invNcdf(1 -Pz);
	end


	%-Print cluster and maximum voxel-level p values {Z}
    	%---------------------------------------------------------------
	h     = text(0.17,y,sprintf(TabDat.fmt{3},Pk),	'FontWeight','Bold',...
		'UserData',Pk,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
	h     = text(0.27,y,sprintf(TabDat.fmt{4},Nv),	'FontWeight','Bold',...
		'UserData',Nv,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
	h     = text(0.35,y,sprintf(TabDat.fmt{5},Pn),	'FontWeight','Bold',...
		'UserData',Pn,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];

	h     = text(0.49,y,sprintf(TabDat.fmt{6},Pu),	'FontWeight','Bold',...
		'UserData',Pu,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
	h     = text(0.57,y,sprintf(TabDat.fmt{7},U),	'FontWeight','Bold',...
		'UserData',U,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
	h     = text(0.66,y,sprintf(TabDat.fmt{8},Ze),	'FontWeight','Bold',...
		'UserData',Ze,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];
	h     = text(0.77,y,sprintf(TabDat.fmt{9},Pz),	'FontWeight','Bold',...
		'UserData',Pz,'ButtonDownFcn','get(gcbo,''UserData'')');
	hPage = [hPage, h];

	h     = text(0.88,y,sprintf(TabDat.fmt{10},XYZmm(:,i)),...
		'FontWeight','Bold',...
		'Tag','ListXYZ',...
		'ButtonDownFcn',...
		'spm_mip_ui(''SetCoords'',get(gcbo,''UserData''));',...
		'Interruptible','off','BusyAction','Cancel',...
		'UserData',XYZmm(:,i));
	HlistXYZ = [HlistXYZ, h];
	if spm_XYZreg('Edist',xyzmm,XYZmm(:,i))<tol & ~isempty(hReg)
		set(h,'Color','r')
	end
	hPage = [hPage, h];
 
	y     = y - dy;
	
	[TabDat.dat{TabLin,3:10}] = deal(Pk,Nv,Pn,Pu,U,Ze,Pz,XYZmm(:,i));
	TabLin = TabLin + 1;

	%-Print Num secondary maxima (> Dis mm apart)
    	%---------------------------------------------------------------
	[l q] = sort(-Z(j));				% sort on Z value
	D     = i;
	for i = 1:length(q)
	    d = j(q(i));
	    if min(sqrt(sum((XYZmm(:,D)-XYZmm(:,d)*ones(1,size(D,2))).^2)))>Dis;

		if length(D) < Num
			
			% Paginate if necessary
			%-----------------------------------------------
			if y < dy
				h = text(0.5,-5*dy,sprintf('Page %d',...
					spm_figure('#page')),...
					'FontName',PF.helvetica,...
					'FontAngle','Italic',...
					'FontSize',FS(8));
				spm_figure('NewPage',[hPage,h])
				hPage = [];
				y     = y0;
			end

			% voxel-level p values {Z}
			%-----------------------------------------------
			Pz    = spm_P(1,0,Z(d),df,STAT,1,n,S);
			Pu    = spm_P(1,0,Z(d),df,STAT,R,n,S);
			if Pz<tol, Ze=Inf; else, Ze = spm_invNcdf(1 - Pz); end

			h     = text(0.49,y,sprintf(TabDat.fmt{6},Pu),...
				'UserData',Pu,...
				'ButtonDownFcn','get(gcbo,''UserData'')');
			hPage = [hPage, h];
			h     = text(0.57,y,sprintf(TabDat.fmt{7},Z(d)),...
				'UserData',Z(d),...
				'ButtonDownFcn','get(gcbo,''UserData'')');
			hPage = [hPage, h];
			h     = text(0.66,y,sprintf(TabDat.fmt{8},Ze),...
				'UserData',Ze,...
				'ButtonDownFcn','get(gcbo,''UserData'')');
			hPage = [hPage, h];
			h     = text(0.77,y,sprintf(TabDat.fmt{9},Pz),...
				'UserData',Pz,...
				'ButtonDownFcn','get(gcbo,''UserData'')');
			hPage = [hPage, h];
			h     = text(0.88,y,...
				sprintf(TabDat.fmt{10},XYZmm(:,d)),...
				'Tag','ListXYZ',...
				'ButtonDownFcn',[...
					'spm_mip_ui(''SetCoords'',',...
					'get(gcbo,''UserData''));'],...
				'Interruptible','off','BusyAction','Cancel',...
				'UserData',XYZmm(:,d));
			HlistXYZ = [HlistXYZ, h];
			if spm_XYZreg('Edist',xyzmm,XYZmm(:,d))<tol & ~isempty(hReg)
				set(h,'Color','r')
			end
			hPage = [hPage, h];
			D     = [D d];
			y     = y - dy;
			[TabDat.dat{TabLin,6:10}] = ...
				deal(Pu,Z(d),Ze,Pz,XYZmm(:,d));
			TabLin = TabLin+1;
		end
	    end
	end
	Z(j) = NaN;		% Set local maxima to NaN
end				% end region


%-Number and register last page (if paginated)
%-----------------------------------------------------------------------
if spm_figure('#page')>1
	h = text(0.5,-5*dy,sprintf('Page %d/%d',spm_figure('#page')*[1,1]),...
		'FontName',PF.helvetica,'FontSize',FS(8),'FontAngle','Italic');
	spm_figure('NewPage',[hPage,h])
end



%-End: Store TabDat in UserData of axes & reset pointer
%=======================================================================
h      = uicontextmenu('Tag','TabDat',...
		'UserData',TabDat);
set(gca,'UIContextMenu',h,...
	'Visible','on',...
	'XColor','w','YColor','w')
uimenu(h,'Label','Table')
uimenu(h,'Separator','on','Label','Print text table',...
	'Tag','TD_TxtTab',...
	'CallBack',...
	'wfu_spm_list99(''txtlist'',get(get(gcbo,''Parent''),''UserData''),3)',...
	'Interruptible','off','BusyAction','Cancel');
uimenu(h,'Separator','off','Label','Extract table data structure',...
	'Tag','TD_Xdat',...
	'CallBack','get(get(gcbo,''Parent''),''UserData'')',...
	'Interruptible','off','BusyAction','Cancel');
uimenu(h,'Separator','on','Label','help',...
	'Tag','TD_Xdat',...
	'CallBack','spm_help(''wfu_spm_list99'')',...
	'Interruptible','off','BusyAction','Cancel');

%-Setup registry
%-----------------------------------------------------------------------
set(hAx,'UserData',struct('hReg',hReg,'HlistXYZ',HlistXYZ))
spm_XYZreg('Add2Reg',hReg,hAx,'wfu_spm_list99');

%-Return TabDat structure & reset pointer
%-----------------------------------------------------------------------
varargout = {TabDat};
spm('Pointer','Arrow')





%=======================================================================
case 'listcluster'                       %-List for current cluster only
%=======================================================================
% FORMAT TabDat = wfu_spm_list99('listcluster',SPM,VOL,Dis,Num,Title,hReg)

spm('Pointer','Watch')

%-Parse arguments
%-----------------------------------------------------------------------
if nargin<3,     error('insufficient arguments'), end
if nargin<7,	 hReg=[]; else, hReg = varargin{7}; end
if nargin<6,     Title = '';
	else,    Title = varargin{6}; end
if isempty(Title), Title = ['single cluster summary',...
			' (p-values corrected for entire volume)']; end
if nargin<5,     Num = [];
	else,    Num = varargin{5}; end
if isempty(Num), Num = Inf; end
if nargin<4,     Dis = [];
	else,    Dis = varargin{4}; end
if isempty(Dis), Dis = 04; end
VOL  = varargin{3};
SPM  = varargin{2};


%-if there are suprathreshold voxels, filter out all but current cluster
%-----------------------------------------------------------------------
if length(SPM.Z)

	%-Jump to voxel nearest current location
	[xyzmm,i] = spm_XYZreg('NearestXYZ',...
			spm_results_ui('GetCoords'),SPM.XYZmm);
	spm_results_ui('SetCoords',SPM.XYZmm(:,i));
	
	%-Find selected cluster
	A         = spm_clusters(SPM.XYZ);
	j         = find(A == A(i));
	SPM.Z     = SPM.Z(j);
	SPM.XYZ   = SPM.XYZ(:,j);
	SPM.XYZmm = SPM.XYZmm(:,j);
	if isfield(VOL,'Rd'), VOL.Rd = VOL.Rd(:,j); end
end

%-Call 'list' functionality to produce table
%-----------------------------------------------------------------------
varargout = {wfu_spm_list99('list',SPM,VOL,Dis,Num,Title,hReg)};





%=======================================================================
case 'txtlist'                                  %-Print ASCII text table
%=======================================================================
% FORMAT wfu_spm_list99('TxtList',TabDat,c)

if nargin<2, error('Insufficient arguments'), end
if nargin<3, c=1; else, c=varargin{3}; end
TabDat = varargin{2};

%-Table Title
%-----------------------------------------------------------------------
fprintf('\n\nSTATISTICS: %s\n',TabDat.tit)
fprintf('%c','='*ones(1,80)), fprintf('\n')

%-Table header
%-----------------------------------------------------------------------
fprintf('%s\t',TabDat.hdr{1,c:end-1}), fprintf('%s\n',TabDat.hdr{1,end})
fprintf('%s\t',TabDat.hdr{2,c:end-1}), fprintf('%s\n',TabDat.hdr{2,end})
fprintf('%c','-'*ones(1,80)), fprintf('\n')

%-Table data
%-----------------------------------------------------------------------
for i = 1:size(TabDat.dat,1)
	for j=c:size(TabDat.dat,2)
		fprintf(TabDat.fmt{j},TabDat.dat{i,j})
		fprintf('\t')
	end
	fprintf('\n')
end
for i=1:max(1,10-size(TabDat.dat,1)), fprintf('\n'), end
fprintf('%s\n',TabDat.str)
fprintf('%c','-'*ones(1,80)), fprintf('\n')

%-Table footer
%-----------------------------------------------------------------------
fprintf('%s\n',TabDat.ftr{:})
fprintf('%c','='*ones(1,80)), fprintf('\n\n')



%=======================================================================
case 'setcoords'                                    %-Co-ordinate change
%=======================================================================
% FORMAT wfu_spm_list99('SetCoords',xyz,hAx,hReg)
if nargin<3, error('Insufficient arguments'), end
hAx = varargin{3};
xyz = varargin{2};
UD  = get(hAx,'UserData');
HlistXYZ = UD.HlistXYZ(ishandle(UD.HlistXYZ));

%-Set all co-ord strings to black
%-----------------------------------------------------------------------
set(HlistXYZ,'Color','k')

%-If co-ord matches a string, highlight it in red
%-----------------------------------------------------------------------
XYZ = get(HlistXYZ,'UserData');
if iscell(XYZ), XYZ = cat(2,XYZ{:}); end
[null,i,d] = spm_XYZreg('NearestXYZ',xyz,XYZ);
if d<eps
	set(HlistXYZ(i),'Color','r')
end


%=======================================================================
otherwise                                        %-Unknown action string
%=======================================================================
error('Unknown action string')


%=======================================================================
end
%=======================================================================
