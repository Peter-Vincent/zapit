classdef waveform_tests < matlab.unittest.TestCase
    % These tests ensure that future changes to the code will not alter the waveforms

    properties
        hZP = [];  % Class instance will go here
        chanSamples % The pre-computed data
        testDataDir = './waveform_tests_data/';
        configFname = 'uniAndBilateral_5_conditions.yml';


    end %properties


    methods(TestClassSetup)
        function buildZapit(obj)
            % Does Zapit build with dummy parameters?
            fprintf('Building Zapit API object\n')
            obj.hZP =  zapit.pointer('simulated',true, ...
                            'settingsFile',fullfile(obj.testDataDir,'zapitSystemSettings.yml'));
            obj.verifyClass(obj.hZP,'zapit.pointer');


            obj.hZP.listeners.saveSettings.Enabled=0; % To ensure the settings are not changed

            % TODO load settings from testDataDir
            fname = fullfile(obj.testDataDir,obj.configFname);
            obj.hZP.loadStimConfig(fname);

            % "calibrate" it. No transformation will be done.
            obj.hZP.refPointsSample = obj.hZP.refPointsStereotaxic;
            % Load data that we previously generated with these conditions
            obj.chanSamples = obj.loadChanSamples;
        end
    end
 
    methods(TestClassTeardown)
        function closeBT(obj)
            fprintf('Closing down Zapit API object\n')
            delete(obj.hZP);
        end
    end





    methods (Test)

        function checkWaveformLengthsMatch(obj)
            %Check that the waveforms were generated correctly
            obj.verifyEqual(size(obj.hZP.stimConfig.chanSamples), size(obj.chanSamples));
        end

        function checkXWaveformsMatch(obj)
             obj.verifyEqual(obj.hZP.stimConfig.chanSamples(:,1,:),obj.chanSamples(:,1,:));
        end

        function checkYWaveformsMatch(obj)
             obj.verifyEqual(obj.hZP.stimConfig.chanSamples(:,2,:),obj.chanSamples(:,2,:));
        end

        function checkLaserWaveformsMatch(obj)
             obj.verifyEqual(obj.hZP.stimConfig.chanSamples(:,3,:),obj.chanSamples(:,3,:));
        end

        function checkBlankinWaveformsMatch(obj)
             obj.verifyEqual(obj.hZP.stimConfig.chanSamples(:,4,:),obj.chanSamples(:,4,:));
        end

        function checkBlankinWaveformsDoNotMatch(obj)
             obj.verifyNotEqual(obj.hZP.stimConfig.chanSamples(:,4,:)+0.1,obj.chanSamples(:,4,:));
        end

        function checkWaveformsDoNotMatch(obj)
            %Check that the waveforms differ if the "calibration" changes
            obj.hZP.refPointsSample(1,1) = obj.hZP.refPointsSample(1,1)+1;
            obj.verifyNotEqual(obj.hZP.stimConfig.chanSamples,obj.chanSamples);
            obj.hZP.refPointsSample = obj.hZP.refPointsStereotaxic; %return it
        end

    end %methods (Test)


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    methods
        % These are convenience methods for running the tests
        function chanSamples  = loadChanSamples(obj);
            fname = fullfile(obj.testDataDir,'chanSamples.mat');
            fprintf('Loading %s\n', fname)
            load(fname);
        end
    end

end %classdef zapit_build_tests < matlab.unittest.TestCase
