classdef TestSetup < matlab.unittest.TestCase
    % Confirms the +dsp package folder is reachable from the MATLAB path.
    methods (Test)
        function packageFolderExists(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.verifyTrue(isfolder(fullfile(root, 'src', '+dsp')));
        end
    end
end
