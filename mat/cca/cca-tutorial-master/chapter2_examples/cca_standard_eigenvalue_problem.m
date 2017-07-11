function [za,zb,wa,wb,cc,ev,C] = cca_standard_eigenvalue_problem(X_a,X_b)

% This function solves canonical correlation analysis through 
% the standard eigenvalue problem.

% Uurtio et al. A Tutorial on Canonical Correlation Methods. 2017.
%--------------------------------------------------------------------------
% Input 
%       X_a: the data matrix of the 1st view (view a)
%       X_b: the data matrix of the 2nd view (view b)

% Output
%       za: the image of the position wa (a.k.a. canonical variate)
%       zb: the image of the position wb (a.k.a. canonical variate)
%       wa: the position in the data space of view a
%       wb: the position in the data space of view b
%       cc: the canonical correlation (cosine of the enclosing angle)
%--------------------------------------------------------------------------
% � 19/01/2017 Viivi Uurtio, Aalto University
% viivi.uurtio@aalto.fi
%
% This code is for academic purposes only.
% Commercial use is not allowed.
%--------------------------------------------------------------------------

n = size(X_a,1); % number of training observations
C_ab = (1/(n-1)) * X_a' * X_b; % sample covariance matrix
C_ba = C_ab'; % transpose of the sample covariance matrix
C_aa = (1/(n-1)) * X_a' * X_a; % empirical variance matrix of view a
C_bb = (1/(n-1)) * X_b' * X_b; % empirical variance matrix of view b
C = [C_aa C_ab; C_ba C_bb];

M = inv(C_bb) * C_ba * inv(C_aa) * C_ab; % the canonical correlation matrix (wishart distributed)
r = min([rank(X_a) rank(X_b)]); % dimensionality of CCA, number of relations

[eigvectors,eigvalues] = eig(M) ; % solve the standard eigenvalue problem
rhos = diag(sqrt(eigvalues)); % canonical correlations
[ev, ind] = sort(rhos,'descend'); % sort in descending order
wb = eigvectors(:,ind); % the positions in the data space of view b

wa = zeros(size(X_a,2),r);
for i = 1:size(wb,2)
    wa(:,i) = (inv(C_aa) * C_ab * wb(:,i)) / ev(i); % positions in the data space of view a
end
 
za = normc(X_a * wa); % image of wa on the surface of the unit ball
zb = normc(X_b * wb); % image of wb on the surface of the unit ball

% the canonical correlations
for i = 1:r
    cc(i) = za(:,i)'*zb(:,i);
end
[cc, ix] = sort(cc,'descend');
za = za(:,ix); zb = zb(:,ix);


end