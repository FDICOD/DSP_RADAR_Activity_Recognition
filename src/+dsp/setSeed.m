function setSeed(seed)
%SETSEED Seed the global random number generator reproducibly.
arguments
    seed (1,1) double {mustBeNonnegative, mustBeInteger}
end
rng(seed, 'twister');
end
