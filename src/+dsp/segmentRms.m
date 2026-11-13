function r = segmentRms(rt, bins)
%SEGMENTRMS Root-mean-square amplitude of the selected range bins.
r = sqrt(mean(abs(rt.data(bins, :)) .^ 2, 'all'));
end
