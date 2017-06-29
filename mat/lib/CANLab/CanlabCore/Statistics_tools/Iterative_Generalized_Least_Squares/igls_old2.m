function out = igls(y, x, varargin)    % function out = igls(y, x, [optional arguments])    %    % Variance Component Estimation using IGLS/RIGLS    %    % y = d + cx + epsilon where z is an optional covariate and epsilon is an AR(p) process    %    % d ~ N(0, sigma_d) and c ~ N(0, sigma_c)    %    % Calculate sigma using the Yule-Walker method. Calculate d, c, b, sigma_d    % and sigma_c using Maximum Likelihood    % methods (IGLS) and Restricted Maximum Likelihood methods (RIGLS).    %    % This program is based on methods which are described in the following    % papers:    %    % Goldstein, H. (1986). Multilevel mixed linear model analysis using    % iterative generalized least squares. Biometrika 73, 43-56.    % Goldstein, H. (1989). Restricted unbiased iterative generalized    % least-squares estimation, Biometrika 76, 622-623.    %    % Inputs:    %    % y - matrix T x subjects    % x - matrix T x subjects    %    % Optional inputs    %    % 'covariate'   includes T x subjects 1st level covariate matrix or     %               subjects x 1 2nd level covariate vector. The dimensions    %               dictate the level.    % 'noverbose'   suppress verbose output    % 'iter'        max number of iterations    % 'type'        'i' for igls (default) or 'r' for rigls    % 'eps'         epsilon for convergence : all changes < (epsilon * beta)    % 'ar'          order of AR(p) process; default is 0 (no AR model)    % 'within_var'  specify common variance within subjects    %    % Outputs: Saved in fields of out.(fieldname)    %    % beta: Group intercept and slope estimates    %   - vector of length 2. Contains estimates of d and c.    %   (d is intercept and c is slope)    % betastar: Between-subjects (2nd level) error estimates    %   - vector of length 2. Contains estimates of sigma_d^2 (intercept variance) and    %   sigma_c^2 (slope variance).    % Sigma: Within-subjects error estimates ****PROBABLY SIGMA^2..check****    %   - vector of length sub. Contains an estimate of sigma for each    %   subject.    % Cov_beta - matrix 2 x 2. Contains covariance matrix for beta.    %   - diagonals are variances, off-diagonals are covariances    %    % Cov_betastar - matrix 2 x 2. Contains covariance matrix for betastar.    % iterations - number of iterations performed    % elapsed_time - amount of time needed to run program    %    % By Martin Lindquist, April 2007    % Edits: Tor Wager, June 2007    %        Martin Lindquist, July 2007    %        Tor and Martin, July 2007    %        Martin, January 2008    %        Tor and Martin, March 2008     %        Martin, July 2008    %        Martin, October 2008    %    % Example: Create simulated data and test    % ----------------------------------------------------------------    % len = 200; sub = 20;    % x = zeros(len,sub);    % x(11:20,:) = 2;                   % create signal    % x(111:120,:) = 2;    %    % c = normrnd(0.5,0.1,sub,1);       % slope between-subjects variations    % d = normrnd(3,0.2,sub,1);         % intercept between-subjects variations    %    % % Create y: Add between-subjects error (random effects) and measurement noise    % % (within-subjects error)    % for i=1:sub, y(:,i) = d(i) + c(i).*x(:,i) + normrnd(0,0.5,len,1);    % end;    %    % out = igls(y, x)  % for igls    % disp('Input random-effect variances: '); disp(std([d c]))    % disp('Est.  random-effect variances: '); disp(sqrt(out.betastar)');    %    % Examples of more complete calls with optional arguments:    % out = igls(y, x, 'type','r', 'iter', 10); beta,betastar    % out = igls(y, x, 'ar', 2,'type','i', 'iter', 10, 'epsilon', .00001); beta, betastar    % out = igls(y, x,'type','r', 'noverbose'); beta,betastar    %    % Small example, for matrix imaging    % len = 20; sub = 5;    randslopevar = 1; randintvar = 1; withinerr = 1;    % fixedslope = 1; fixedint = 1;    % x = zeros(len,sub); x(1:2:10, :) = 1;  % fixed-effect signal (same for all subs)    % c = normrnd(fixedslope,randslopevar,sub,1);       % slope between-subjects variations    % d = normrnd(fixedint,randintvar,sub,1);  % intercept between-subjects variations    % clear y    % for i=1:sub, y(:,i) = d(i) + c(i).*x(:,i) + normrnd(0,withinerr,len,1); end    % out = igls(y, x, 'plot', 'all')  % for igls    %    %     % Example: Simulation with second level covariate    %    %    %     len = 200; sub = 20;    %     x = zeros(len,sub);    %     x(11:20,:) = 2;                   % create signal    %     x(111:120,:) = 2;    %         %     c = normrnd(0.5,0.1,sub,1);       % slope between-subjects variations    %     d = normrnd(3,0.2,sub,1);         % intercept between-subjects variations    %         %     for i=1:sub, y(:,i) = d(i) + c(i).*x(:,i) + 2*i + normrnd(0,0.5,len,1); end;    %         %     out = igls(y, x,'covariate',(1:20));  % for igls    %     disp('Input random-effect variances: '); disp(std([d c]))    %     disp('Est.  random-effect variances: '); disp(sqrt(out.betastar)');    %                   % Programmers' notes    % --------------------------------------------------------------------    %    % Created 5/29/2007 by Martin Lindquist    % Edits: 5/29, Tor; minor code rearrangement; results identical with    %   original version on test data    %   Replaced epsilon with data-dependent criterion    %   Speeded up code : almost 2 x as fast with \ operator and avoiding    %   growing arrays    %   1.69 s on example code for 5 iterations    %   Added optional arguments: type and verbose    % Edits: 7/1, Martin; Edited solution of betastar. Edited bug that    %   was underestimating the variance of betastar. Included option    %   to allow for common within subject variance acroos subjects.    % Edits 7/13: Tor: plotting functions, optional inputs, more bookkeeping    %   stuff    % Edits: 1/14/08: Martin: Implemented Likelihood Ratio Test for testing    %   the significance of the variance components.    % Edits: 3/7/08: T & M: take cell inputs /optional    % Edits: 7/14/08: Martin: Allowed for either 1st or 2nd level covariate.    %     % Simulation: No random effects    %     len = 200; sub = 20;    % x = zeros(len,sub);    % x(11:20,:) = 2;                   % create signal    % x(111:120,:) = 2;    % c = normrnd(0.5,.1,sub,1);       % slope between-subjects variations    % d = normrnd(3,.3,sub,1);         % intercept between-subjects variations    % y = x;    % figure; imagesc(y)    % y = x;    % % Add between-subjects error (random effects) and measurement noise    % % (within-subjects error)    % for i=1:sub, y(:,i) = d(i) + c(i).*x(:,i) + normrnd(0,0.5,len,1);    % end;    % out = igls(y, x, 'type', 'r');  % for igls    % disp('Input random-effect variances: '); disp(std([d c]))    % disp('Est.  random-effect variances: '); disp(sqrt(out.betastar)');     c1= clock;     % outputs    Phi = [];     % defaults    % -------------------------------------------------------------------     epsilon = 0.01;                % Convergence criterion: Min change in beta * epsilon    num_iter = 5;    doverbose = 1;    docovariate = 0;    level = 1;                     % Determines which level to apply covariate    arorder = 0;                   % or Zero for no AR    type = 'i';    within = 'common';    % doplot = 'slopes';    doplot='none';    beta_names = {'Intcpt.' 'Slope1'};  % default names     % optional inputs    % -------------------------------------------------------------------%     for varg = 1:length(varargin)%         if ischar(varargin{varg})%             switch varargin{varg}% %                 % reserved keywords%                 case 'verbose', doverbose = 1;%                 case 'noverbose', doverbose = 0;%                     %             end%         end%     end     for varg = 1:length(varargin)        if ischar(varargin{varg})            switch varargin{varg}                % reserved keywords                case 'covariate', docovariate = 1; x_c = varargin{varg+1};                case 'verbose', doverbose = 1;                case 'noverbose', doverbose = 0;                case {'iterations', 'iter'}, num_iter = varargin{varg+1};                case 'type', type = varargin{varg+1}; varargin{varg+1} = [];                case {'epsilon', 'eps'}, epsilon = varargin{varg+1};                case {'ar', 'arorder'} , arorder = varargin{varg+1};                case {'within_var', 'within'} , within = 'unique_est';                case {'noplot'}, doplot = 'off';                case {'plot'}, doplot = varargin{varg + 1}; varargin{varg + 1} = [];                case 'names', beta_names = varargin{varg + 1};                 otherwise, if doverbose, disp(['Unknown input string option: ' varargin{varg}]); end             end        end    end     % enforce matrix, padding if necessary; convert from cell input if    % necessary    [y, x] = cell2matrix(y, x);             % check type        switch type        case 'i', analysisname = 'IGLS: Iterative generalized least squares analysis';        case 'r', analysisname = 'RIGLS: Restricted iterative generalized least squares analysis';        otherwise            error('Type must be ''i'' (igls) or ''r'' (rigls)');    end          % sizes, etc.    % -------------------------------------------------------------------     % T,        time points for subjects (same across subjects)    % sub,      number of subjects    % T2,       num. elements in lower triangle of cov matrix    % len =     total # obs    % n_G       # rows in G    % z         data, (Y1 Y2 ... Ysub)'    % D         within-subjects design, blk diagonal     [T, sub] = size(y);                             % Length of y vector (Time) x Number of subjects    T2 = T * (T + 1) ./ 2;                          % num. elements in lower triangle of cov matrix    len = sub * T;                                  % Total number of observations    n_G = sub * T2;                                 % number of rows in var-comp est. design matrix     z = reshape(y,len,1);                           % Concatenated data, T within sub            if (docovariate == 1)         % If x_c is a vector than covariate is applied to 2nd level, if it is a        % matrix than it is applied to the 1st level        switch numel(x_c)            case sub                % Set-up second level covariates                % enforce column format input                if length(x_c) > size(x_c, 1), x_c = x_c'; end                                  x_c = scale(x_c, 1);                   % Mean-center covariates across sub                x_c = repmat(x_c',T,1);                level = 2;            case len                % We have first-level covariate, T x sub                                 x_c = scale(x_c, 1);                   % Mean-center covariates across time                level = 1;            otherwise                error(sprintf('Covariate must be %3.0f x 1 vector for 2nd level or %3.0f x %3.0f matrix for 1st level', sub, sub, T));        end                xvec = reshape(x,len,1);        x_cvec = reshape(x_c,len,1);        %         D = [zeros(len,1)+1 xvec x_cvec xvec.*x_cvec];          % Design matrix        beta_names = {'Intcpt. (1st level)' 'Slope1 (1st level)', 'Covariate_x_intcpt (2nd level)', 'Covariate_x_slope (2nd level)'};        D = [ones(len,1) xvec];        % design matrix, for later        D1 = [x_cvec xvec.*x_cvec];    % covariate design matrix; cov on intercept, then cov * slope (cov * x)        beta_c = D1\(z - nanmean(z));        z = z - D1 * beta_c;             % use residuals for within-subjects effects below        sig_c = z'*z / (len-2);         % sigma^2, SS / df        Cov_beta_c = sig_c .* inv(D1'*D1);  % sigma^2 * inv(X'X)    else                D = [zeros(len,1)+1 reshape(x,len,1)];          % Design matrix    end        % Remove NaNs    [whnan, D, z] = nanremove(D, z);        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    %    % Step 1: Find the OLS solution    %    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     beta = D \ z;                                           % Beta values    resid = z - D * beta;                                   % Residuals            % Create regressors corresponding to within subject variance.    % Dimensions depend on whether one assumes common variance across    % subjects.        if (strcmp(within, 'common'))        V = zeros(n_G,1);        ind_c = zeros(1,4)+1;        ind_d = zeros(1,4)+1;    else        V = zeros(n_G,sub);        ind_c = zeros(1,3+sub)+1;        ind_d = zeros(1,3+sub)+1;    end     Sigma = zeros(sub,1);     Sig = zeros(len,len);                         % Covariance matrix    iSig = eye(len,len);                          % Inverse of covariance matrix     Sig_no_d = zeros(len,len);                    % Covariance matrix for reduced model with sigma_d=0 (needed for LRT).    iSig_no_d = eye(len,len);                     % Inverse of covariance matrix        Sig_no_c = zeros(len,len);                    % Covariance matrix for reduced model with sigma_c=0 (needed for LRT).    iSig_no_c = eye(len,len);                     % Inverse of covariance matrix        if arorder > 0        Phi = zeros(sub,arorder);        get_ar                                              % updates Phi, Sigma, and -> V (from Sigma)    else        get_V_no_ar    end     ystar = zeros(n_G, 1);                                  % Sums of squared residuals, concatenated across Ss    ystar_no_c = zeros(n_G, 1);                             % SSR for reduced model 1            ystar_no_d = zeros(n_G, 1);                             % SSR for reduced model 2           resid_no_c = resid;                                     % Set temporary values needed for first iteration.    resid_no_d = resid;     get_ystar;     % Fit the variance parameter design matrix to ystar, est. residual variances     G = Create_Design_Eq2(x,V);                             % Create design matrix for variance estimation    betastar = G \ ystar;                                   % Estimate variance components    betastar(betastar < 0) = 0;                             % Use max(0,betastar) to ensure nonnegative variance.       % Reduced model 1    ind_d(1) = 0;    ind_d(3) = 0;    tt_d = (ind_d == 1);    betastar_no_d = G(:,tt_d) \ ystar;                      % Estimate variance components when sigma_d=0    betastar_no_d(betastar_no_d < 0) = 0;                   % Use max(0,betastar) to ensure nonnegative variance.     % Reduced model 2    ind_c(2) = 0;    ind_c(3) = 0;    tt_c = (ind_c == 1);    betastar_no_c = G(:,tt_c) \ ystar;                      % Estimate variance components when sigma_c=0    betastar_no_c(betastar_no_c < 0) = 0;                   % Use max(0,betastar) to ensure nonnegative variance.         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    %    % Step 2: Iterate    %    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     iterations = 0;    min_change = betastar * epsilon;     isconverged = 0;     while (iterations < num_iter) && ~isconverged        num = size(G,1) / sub;        for s = 1:sub             Sig1 = ivech(G(((s-1) * num + 1):(s * num),:) * betastar);            Sig1 = Sig1 + tril(Sig1,-1)';             wh = ((s-1)*T+1):(s*T);                   % which indices in Cov mtx for this subject            Sig(wh, wh) = Sig1;            iSig(wh, wh) = inv(Sig(wh, wh));                        % Cov mtx when sigma_d =0             Sig1_no_d = ivech(G(((s-1) * num + 1):(s * num),tt_d) * betastar_no_d);            Sig1_no_d = Sig1_no_d + tril(Sig1_no_d,-1)';            Sig_no_d(wh, wh) = Sig1_no_d;            iSig_no_d(wh, wh) = inv(Sig_no_d(wh, wh));                        % Cov mtx when sigma_c =0             Sig1_no_c = ivech(G(((s-1) * num + 1):(s * num),tt_c) * betastar_no_c);            Sig1_no_c = Sig1_no_c + tril(Sig1_no_c,-1)';            Sig_no_c(wh, wh) = Sig1_no_c;            iSig_no_c(wh, wh) = inv(Sig_no_c(wh, wh));         end         beta = inv(D'*iSig*D)*D'*iSig*z;                        % Beta values        resid = z - D*beta;                                     % Residuals         beta_no_d = inv(D'*iSig_no_d*D)*D'*iSig_no_d*z;         % Beta values when sigma_d=0        resid_no_d = z - D*beta_no_d;                           % Residuals         beta_no_c = inv(D'*iSig_no_c*D)*D'*iSig_no_c*z;         % Beta values when sigma_c=0        resid_no_c = z - D*beta_no_c;                           % Residuals                betastar_old = betastar;         get_ystar;              beta_indiv = get_indiv_betas;   % params x subjects matrix of betas                betastar = G \ ystar;        betastar(betastar < 0) = 0;                             % Use max(0,betastar) to ensure nonnegative variance.         betastar_no_d = G(:,tt_d) \ ystar_no_d;        betastar_no_d(betastar_no_d < 0) = 0;                   % Use max(0,betastar) to ensure nonnegative variance.         betastar_no_c = G(:,tt_c) \ ystar_no_c;        betastar_no_c(betastar_no_c < 0) = 0;                   % Use max(0,betastar) to ensure nonnegative variance.         isconverged = ~any(abs(betastar - betastar_old) > abs(min_change));        iterations = iterations + 1;     end     Cov_beta = inv(D'*iSig*D);    %W = (Sigma - D*inv(D'*iSigma*D)*D');        % Residual inducing matrix x Sigma    df_beta = sub - 1;          % this should be sub - q, # params in Xg, but we haven't added this flexibility yet     %df_beta = (trace(W).^2)./trace(W*W);       % Satterthwaite approximation for degrees of freedom     Cov_betastar = inv(G'*G);    df_betastar = sub - 1;    Sigma = betastar(4:end);        yhat = G*betastar;    e = ystar - yhat;    tau = e'*e/(size(G,1)-size(G,2));          %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    % Likelihood ratio tests    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    detmat = zeros(sub,1);    detmat_no_d = zeros(sub,1);    detmat_no_c = zeros(sub,1);    detDSigD = 0;    detDSigD_no_d = 0;        detDSigD_no_c = 0;    for k=1:sub,                wh = ((k-1) * T + 1):(k * T);        detmat(k) = abs(det(Sig(wh,wh)));        detmat_no_d(k) = abs(det(Sig_no_d(wh,wh)));        detmat_no_c(k) = abs(det(Sig_no_c(wh,wh)));    detDSigD = detDSigD+abs(det(D(wh,:)' * iSig(wh,wh) * D(wh,:)));    detDSigD_no_d = detDSigD_no_d+abs(det(D(wh,:)' * iSig_no_d(wh,wh) * D(wh,:)));        detDSigD_no_c = detDSigD_no_c+abs(det(D(wh,:)' * iSig_no_c(wh,wh) * D(wh,:)));    end;      %     detDSigD = abs(det(D' * iSig * D));%     detDSigD_no_d = abs(det(D' * iSig_no_d * D));    %     detDSigD_no_c = abs(det(D' * iSig_no_c * D));%          % Test H0: sigma_d =0                LLd = - 0.5*( sum(log(detmat_no_d))-sum(log(detmat)) + (resid_no_d'* iSig_no_d * resid_no_d - resid'* iSig * resid));    if (type == 'r'),        LLd = -0.5*(log(detDSigD_no_d) - log(detDSigD) + sum(log(detmat_no_d))-sum(log(detmat)) +...            (resid'* iSig_no_d * resid - resid'* iSig * resid));         end;    LRd = max(-2*LLd,0);%    randvariance_d = 1-chi2cdf(LRd,1);       %Make it a 50:50 mixture     V = 0.5*(chi2rnd(1,1000000,1)) + 0.5*(chi2rnd(2,1000000,1));    randvariance_d = mean(V>LRd);    % Test H0: sigma_c =0    LLc = - 0.5*( sum(log(detmat_no_c))-sum(log(detmat)) + (resid_no_c'* iSig_no_c * resid_no_c - resid'* iSig * resid));    if (type == 'r'),        LLc = -0.5*(log(detDSigD_no_c) - log(detDSigD) + sum(log(detmat_no_c))-sum(log(detmat)) +...            (resid'* iSig_no_c * resid - resid'* iSig * resid));       end;    LRc = max(-2*LLc,0); %   randvariance_c = 1-chi2cdf(2*LRc,1);      randvariance_c = mean(V>LRc);            betastar = betastar(1:2);                       % Remove within subject variance    Cov_betastar = Cov_betastar(1:2,1:2);           % Remove within subject variance    % Include covariates in output    if (docovariate == 1)        if (level == 2)            Cov_beta = blkdiag(Cov_beta, Cov_beta);            beta = [beta; beta_c];        else            Cov_beta = blkdiag(Cov_beta, Cov_beta_c);            beta = [beta; beta_c];        end    end    c2 = clock;    elapsed_time = etime(c2, c1);       % save output structure     names = {'Y1'}; % later;    varnames = {'analysisname', 'names', 'beta_names', 'type', 'num_iter', 'epsilon', 'arorder', 'within', 'y', 'x'};    inputOptions = create_struct(varnames);     out = struct('analysisname', analysisname, 'beta', beta, 'betastar', betastar, 'beta_indiv', beta_indiv, 'beta_names', {beta_names}, ...        'Cov_beta', Cov_beta, 'Cov_betastar', Cov_betastar, ...        'Sigma', Sigma, 'Phi', Phi, ...        'type', type, 'arorder', arorder, 'isconverged', isconverged, ...        'num_obs', T, 'sub', sub, 'num_iter', num_iter, 'epsilon', epsilon, ...        'iterations', iterations, 'elapsed_time', elapsed_time, 'inputOptions', inputOptions);     % save stats    out.ste = sqrt(diag(out.Cov_beta));     out.t = out.beta ./ out.ste;    out.df_beta = df_beta;    out.p = 2 * (1 - tcdf(abs(out.t), out.df_beta));  % two-tailed    out.p(out.p == 0) = eps;    out.p_tails = 'two-tailed';     out.t_randvariance = out.betastar ./ sqrt(diag(out.Cov_betastar));    out.df_betastar = df_betastar;    out.p_randvariance = (1 - tcdf(abs(out.t_randvariance), out.df_betastar)); % one-tailed    out.p_randvariance(out.p_randvariance == 0) = eps;    out.p_randvariance_tails = 'one-tailed';        out.LRT = [LRd; LRc];    out.pLRT_randvariance = [randvariance_d; randvariance_c];               if strcmp(doplot, 'all')         plot_igls_matrices        igls_plot_slopes(out, x);            elseif strcmp(doplot, 'slopes')                igls_plot_slopes(out, x);            end     % print output    if doverbose        print_output_text(out)    end % _________________________________________________________________________%%%% * Inline (nested) functions%%%%__________________________________________________________________________      function newstruct = create_struct(varnames)         newstruct = struct();         for i = 1:length(varnames)            eval(['newstruct.(varnames{i}) = ' varnames{i} ';']);        end     end       function [beta_indiv] = get_indiv_betas        % beta_indiv is params x subjects matrix         % Reexpress design matrix depending on whether or not the covariate        % is applied to the 1st or second level.        DD = D;        if (level == 2)            DD = DD(:,1:(end-1));       %Remove second level covariate from design matrix        end                beta_indiv = zeros(size(DD,2),sub);         for k = 1:sub            % Estimate AR parameters using the Yule-Walker method for each subject.            wh = ((k-1) * T + 1):(k * T);            beta_indiv(:,k) = inv(DD(wh,:)' * iSig(wh,wh) * DD(wh,:)) * DD(wh,:)' * iSig(wh,wh) * z(wh, 1);            sigma_indiv(k) = mean(diag(Sig(wh, wh)));                        %% for plotting: need weight estimates for each subject                    end     end     function get_V_no_ar         mysig = vech(eye(T));         for k = 1:sub            wh = ((k-1) * T2 + 1):(k * T2);                             % indices in time series for this subject            if (strcmp(within, 'common'))                V(wh) = mysig;                                          % Create one regressor for common variance            else                V(wh,k) = mysig;                                        % Cretae m regressors otherwise            end        end    end      function get_ar         % %         beta_indiv = zeros(size(D,2),sub);         for k = 1:sub            % Estimate AR parameters using the Yule-Walker method for each subject.            wh = ((k-1) * T + 1):(k * T);             % %             beta_indiv(:,k) = (D(wh,:) \ z(wh));            % %             res = z(wh) - (D(wh,:) * beta_indiv(:,k));             [a,e] = aryule(resid(wh), arorder);                % Yule-Walker            Phi(k,:) = a(2:(arorder+1));                 % Parameters of AR(p) model            Sigma(k) = sqrt(e);                          % standard deviation of AR(p) model; ***not used?***             % Find the covariance matrix             A = diag(ones(T,1));            for j=1:arorder                A = A + diag(Phi(k,j)*ones((T-j),1),-j);            end             wh = ((k-1) * T2 + 1):(k * T2);                             % indices in time series for this subject            iA = inv(A);            tmp = vech(iA * iA');            if strcmp(within, 'common')                %                V(wh) = Sigma(k)^2 * tmp;                                      % Covariance function in vech format                V(wh) = tmp;                                      % Covariance function in vech format            else                %                V(wh,k) = Sigma(k)^2 * tmp;                                      % Covariance function in vech format                V(wh,k) = tmp;                                      % Covariance function in vech format            end          end    end      function get_ystar        if (type == 'i')           % IGLS            for i=1:sub                wh = ((i-1) * T + 1):(i * T);                              % indices in time series for this subject                myresid = resid( wh );                                     % residuals for this subject.                myresid_no_c = resid_no_c(wh );                myresid_no_d = resid_no_d(wh );                                tmp = vech(myresid * myresid');                            % Find vech of estimated covariance                tmp_no_c = vech(myresid_no_c * myresid_no_c');                                            tmp_no_d = vech(myresid_no_d * myresid_no_d');                                                           wh = ((i-1) * T2 + 1):(i * T2);                            % indices in time series for this subject                ystar(wh) = tmp;                ystar_no_c(wh) = tmp_no_c;                ystar_no_d(wh) = tmp_no_d;            end        elseif (type == 'r')       % RIGLS                        DD = D;            if (level == 2)                DD = DD(:,1:(end-1));       %Remove second level covariate from design matrix            end                        for i=1:sub                wh = ((i-1) * T + 1):(i*T);                                  % indices in time series for this subject                Dtmp = DD(wh, :);                rtmp = resid(wh);                                            % residuals for this subject.                rtmp_no_c = resid_no_c(wh);                 rtmp_no_d = resid_no_d(wh);                                wh = ((i-1) * T2 + 1):(i * T2);                Vtmp = V(wh);                U = ivech(Vtmp);                iU = inv(U);                iU_no_c = iU;                iU_no_d = iU;                                %                 iU = iSig(wh,wh);%                 iU_no_c = iSig_no_c(wh,wh);%                 iU_no_d = iSig_no_d(wh,wh);                rig = rtmp * rtmp' + Dtmp * inv(Dtmp' * iU * Dtmp) * Dtmp';                tmp = vech(rig);                                                       % Find vech of estimated covariance                rig_no_c = rtmp_no_c * rtmp_no_c' + Dtmp * inv(Dtmp' * iU_no_c * Dtmp) * Dtmp';                tmp_no_c = vech(rig_no_c);                                             % Find vech of estimated covariance                rig_no_d = rtmp_no_d * rtmp_no_d' + Dtmp * inv(Dtmp' * iU_no_d * Dtmp) * Dtmp';                tmp_no_d = vech(rig_no_d);                                             % Find vech of estimated covariance                           wh = ((i-1) * T2 + 1):(i * T2);                                % indices in time series for this subject                ystar(wh) = tmp;                ystar_no_c(wh) = tmp_no_c;                ystar_no_d(wh) = tmp_no_d;            end        end    end      function plot_igls_matrices         % Ystar_mtx:    Estimate of total covariance, var(ksi)        Ystar_mtx = single(resid * resid');         figh = create_figure(['IGLS Error Matrix Plot'], 2, 4);        for i = 1:7, subplot(2, 4, i); set(gca,'YDir', 'reverse'); end        subplot(2, 4, 8); axis off         titles = {'Cov(ksi) est.' 'Random intercept' 'Random slope' 'Within error' 'Fitted' 'residual'};         subplot(2, 4, 1);        s = std(Ystar_mtx(:));        clims = [-3 * s   3 * s];         imagesc(Ystar_mtx, clims)         title(titles{1})        xlabel('T * N');        ylabel('T * N');        axis image        text(T*sub + .01*T*sub, T*sub/2, '=','FontSize', 64)         % set color map; make zero values white        cm = zeros(256, 3);        cvec = abs(linspace(clims(1), clims(2), size(cm, 1)));        wh = find(cvec == min(cvec));        wh = wh(1);        hotpart = [linspace(.9, 1, length(cvec) - wh + 1)' linspace(1, 0, length(cvec) - wh + 1)' linspace(0, 0, length(cvec) - wh + 1)'];        cm(wh:end, :) = hotpart(end:-1:1, :);         coolpart = [linspace(0, 0, wh - 1)' linspace(0, 1, wh - 1)' linspace(1, .9, wh - 1)'];        cm(1:wh - 1, :) = coolpart;         cm(wh-1:wh+1, :) = repmat([.3 .3 .3], 3, 1);        colormap(cm)        drawnow         num_var_comps = size(G, 2) - length(Sigma);         % GGmtx: Cell array of matrix error covariance components        % -----------------------------------------        myest = [betastar; Sigma];        GGfit = sparse(zeros(T*sub, T*sub));         % get var. component matrices, not including Sigma (within error)        for k = 1:num_var_comps             for i = 1:sub                wh = ((i-1) * T2 + 1):(i * T2);                             % indices in time series for this subject                GG{i} = ivech(G(wh, k));            end             % fitted for this component            GGmtx{k} = sparse(blkdiag(GG{:})) .* myest(k);             GGmtx{k} =  full_from_ltr( GGmtx{k} ); % full matrix form from lower triangle             GGfit = GGfit + GGmtx{k};          end         % now get the one for sigma (V)        % -----------------------------------------        wh_is_V = num_var_comps + 1;        GGmtx{wh_is_V} = sparse(zeros(T * sub, T * sub));         for k = 1:length(Sigma)            for i = 1:sub                wh = ((i-1) * T2 + 1):(i * T2);                             % indices in time series for this subject                GG{i} = ivech(G(wh, num_var_comps + k));            end             % fitted error            GGmtx{wh_is_V} = GGmtx{wh_is_V} + sparse(blkdiag(GG{:})) .* myest(num_var_comps + k);        end         GGmtx{wh_is_V} =  full_from_ltr( GGmtx{wh_is_V} ); % full matrix form from lower triangle         GGfit = GGfit + GGmtx{wh_is_V};         % image them        % -----------------------------------------        for k = 1:num_var_comps + 1            subplot(2, 4, k + 1);            imagesc(GGmtx{k}, clims);             title(sprintf('%s\nb-hat = %3.3f', titles{k+1}, myest(k)));            axis image            if k <= num_var_comps, text(T*sub + .01*T*sub, T*sub/2, '+','FontSize', 64), end            drawnow        end         subplot(2, 4, num_var_comps + 3);        imagesc(GGfit, clims)        title(titles{5})        axis image        drawnow         residmtx = double(Ystar_mtx) - GGfit;        clear GGfit        fprintf('MST (diag of Ystar_mtx): %3.5f\n', mean(diag(Ystar_mtx)));        fprintf('MSE (diag of resid): %3.5f\n', mean(diag(residmtx)));         axh = subplot(2, 4, num_var_comps + 4);        imagesc(residmtx, clims)        title(titles{6})        axis image        drawnow         axh2 = subplot(2, 4, num_var_comps + 5);        axes(axh2)        imagesc(residmtx, clims)        colorbar; %('peer', axh);        set(axh2,'Visible','off')     end   end % END MAIN FUNCTION  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Subfunctions%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% function G = Create_Design_Eq2(x,V)    % function G = Create_Design(x)    %    % Create Design matrix for estimation of variance components    %    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     [T, sub] = size(x);    T2 = T * (T+1) / 2;    one = zeros(T,1) + 1;    G = zeros(sub * T2, 3);     for i = 1:sub        wh = ((i-1) * T2 + 1):(i * T2);        G(wh,1) = vech(one*one');                      % Regressor corresponding to sigma_d^2        G(wh,2) = vech(x(:,i) * x(:,i)');                 % Regressor corresponding to sigma_c^2        G(wh,3) = vech(one * x(:,i)' + x(:,i) * one');                 % Regressor corresponding to sigma_dc    end     G = [G V];                              % use within-subject covariance as a regressor end  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% function V = vech(Mat)    % function V = vech(Mat)    %    % Calculate vech for the matrix Mat    %    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     V = Mat(tril(true(size(Mat)))); end  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% function Mat = ivech(V)    % function Mat = vech(V)    %    % Calculate the "inverse" of the vech function    % This is much faster than matlab's squareform.m    % It could be speeded up, probably, by operating column-wise    %    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     len = length(V);    dim = -0.5 + sqrt(0.25 + 2 * len);    Mat = zeros(dim, dim);    ind=1;     for i=1:dim        for j=i:dim            Mat(j,i) = V(ind);            ind = ind+1;        end    endend %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% function print_output_text(out)    fprintf('\nigls.m output report:\n---------------------------------------\n');    fprintf('Data: %3.0f observations x %3.0f subjects \n', out.num_obs, out.sub);    typestr = {'igls' 'rigls'};    nystr = {'No' 'Yes'};    fprintf('Fit Type: %s\n', typestr{strcmp(out.type, 'r') + 1});    fprintf('AR(p) model: %s', nystr{(out.arorder > 0) + 1});    if out.arorder > 0        fprintf(', AR(%d)\n', out.arorder);    else        fprintf('\n');    end     fprintf('Converged: %s\n', nystr{out.isconverged + 1});    fprintf('Max iterations: %3.0f, Completed iterations: %3.0f\n', out.num_iter, out.iterations);    fprintf('Epsilon for convergence: %3.6f\n', out.epsilon);    fprintf('Elapsed time: %3.2f s\n', out.elapsed_time);     fprintf('\nStatistics: Tests of inference on fixed population parameters\n')    fprintf('Parameter\test.\tt(%3.0f)\tp\t\n', out.df_beta)    sigstring = {' ' '+' '*' '**' '***'};     for i = 1:length(out.beta)        % if i == 1, name = 'Intcpt.'; else name = ['Pred' num2str(i - 1)]; end   % names input above, at start        sig = out.p(i) < [Inf .1 .05 .01 .001];        fprintf('%s\t%3.3f\t%3.2f\t%3.6f\t%s\n', out.beta_names{i}, out.beta(i), out.t(i), out.p(i), sigstring{find(sig, 1, 'last')})    end     fprintf('\n\nStatistics: Tests of significance on random effects (variances)\n')%    fprintf('Parameter\test.\tt(%3.0f)\tp\t\n', out.df_betastar)    fprintf('Parameter\test.\tLRT\tp\t\n')    sigstring = {' ' '+' '*' '**' '***'};     for i = 1:length(out.beta)        %if i == 1, name = 'Intcpt.'; else name = ['Pred' num2str(i - 1)]; end        if (~strcmp(out.beta_names(i),'Covariate_intcpt') && ~strcmp(out.beta_names(i),'Covariate_slope'))            %            sig = out.p_randvariance(i) < [Inf .1 .05 .01 .001];            %           fprintf('%s\t%3.3f\t%3.2f\t%3.6f\t%s\n', out.beta_names{i}, out.betastar(i), out.t_randvariance(i), out.p_randvariance(i), sigstring{find(sig, 1, 'last')})            if i <= length(out.pLRT_randvariance)                sig = out.pLRT_randvariance(i) < [Inf .1 .05 .01 .001];                fprintf('%s\t%3.3f\t%3.2f\t%3.6f\t%s\n', out.beta_names{i}, out.betastar(i), out.LRT(i), out.pLRT_randvariance(i), sigstring{find(sig, 1, 'last')})            end        end    end     fprintf('\n---------------------------------------\n\n');end %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        function M = full_from_ltr(M)     tmp2 = M;    tmp2 = (  tmp2 .*  (1 - eye(size(tmp2)))  )';    M = M + tmp2; end     % This duplicates a function in the SCN Core toolbox, but is included to% make igls.m stand-alone function f1 = create_figure(tagname, varargin)    % f1 = create_figure(['tagname'], [subplotrows], [subplotcols], [do not clear flag])    %    % checks for old figure with tag of tagname    % clears it if it exists, or creates new one if it doesn't     if nargin < 1 || isempty(tagname)        tagname = 'nmdsfig';    end     doclear = 1;    % clear if new or if old and existing    if length(varargin) > 2 && varargin{3}        % use same figure; do not clear        doclear = 0;    end     old = findobj('Tag', tagname);     if ~isempty(old)         if doclear, clf(old); end         f1 = old;     else        % Or create new         scnsize = get(0,'ScreenSize');         xdim = min(scnsize(3)./2, 700);        ydim = min(scnsize(4)./2, 700);         f1 = figure('position',round([50 50 xdim ydim]),'color','white');        set(f1, 'Tag', tagname, 'Name', tagname);    end     % activate this figure    figure(f1);      if doclear % true for new figs or cleared ones         % Create subplots, if requested; set axis font sizes         if length(varargin) > 0            i = max(1, varargin{1});            j = max(1, varargin{2});        else            i = 1;            j = 1;        end         np = max(1, i * j);         for k = 1:np            axh(k) = subplot(i,j,k);            set(gca,'FontSize',18),hold on        end        axes(axh(1));     end end  function [y, x] = cell2matrix(y, x)        % one or none of y and x can be cell arrays    if ~iscell(x) && ~iscell(y)        return    end                if iscell(y)                if ~iscell(x), error('y and x must either both be cell arrays or neither can be.'); end                sz = zeros(size(y, 1), 2);        for i = 1:length(y)            sz(i, :) = size(y{i});        end          sz = sz(:, 1);         if all(sz) == sz(1)            % all the same?        else             mx = max(sz(:, 1));  % longest             for i = 1:length(y)                 if sz(i) < mx                    mn = mean(y{i});                    mnx = mean(x{i});                     y{i} = [y{i}; mn(ones(mx - sz(i), 1))];                     % assume y and x match and are both cells                    x{i} = [x{i}; mnx(ones(mx - sz(i), 1))];                end            end        end         %turn into matrix        y = cell2mat(y);        x = cell2mat(x);     end    end     