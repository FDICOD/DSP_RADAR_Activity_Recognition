function w = balancedWeights(y)
%BALANCEDWEIGHTS Per-recording weights that give every class the same total weight.
%   w = dsp.balancedWeights(y): weight N / (K * n_c) for a recording of class c,
%   so rare classes (such as falling) count as much as common ones in training.
y = y(:);
classes = unique(y);
w = zeros(size(y));
for c = classes'
    members = y == c;
    w(members) = numel(y) / (numel(classes) * nnz(members));
end
end
