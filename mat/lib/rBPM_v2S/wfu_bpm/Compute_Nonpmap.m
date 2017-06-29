function [Romap] = Compute_Nonpmap(Pvalue,brain_mask,Romap,M,N)
%---------- computing Fmaps for regression ------------------%
[R C B] = size(Tvalue);
for m = 1:M
    for n = 1:N
        if brain_mask(m,n) == 1
                Romap(m,n) = invt(Pvalue(m,n),dof(m,n));
        end
    end
end