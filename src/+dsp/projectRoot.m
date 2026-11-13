function root = projectRoot()
%PROJECTROOT Absolute path of the project folder (the one containing src/).
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
