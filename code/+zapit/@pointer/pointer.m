classdef pointer < handle
    
    % pointer
    %
    % Drives a galvo-based photo-stimulator. Scan lens doubles as an
    % objective to scan the beam over the sample and also to form an
    % image via a camera.
    %
    %
    % Maja Skretowska - SWC 2020-2022
    % Rob Campbell - SWC 2020...


    
    properties
        % TODO -- The following properties need to be in a settings structure
        % 0/0 volts on DAQ corresponds to the middle of the image
        invertX = true
        invertY = true

        % The following are associated with hardware components
        cam % camera
        DAQ % instance of class that controls the DAQ (laser and scanners)


        % The following properties relate to settings or other similar state parameters
        % Properties related to where we stimulate
        settings % The settings read in from the YAML file
        config % Object of class zapit.config. This contains the locations to stimulate
        %Laser stuff. TODO -- this might move to a separate class but for now it stays here
        laserFit  % laserfits. See generateLaserCalibrationCurve
        transform % The transform describing the relationship between scanners and camera


        % The following relate to running the behavioral task itself
        coordsLibrary % TODO - I think this is where all computed waveforms are kept
        newpoint % TODO - ??
        chanSamples %Structure describing waveforms to send the scanners for each brain area
        waveforms % The last set of waveforms sent to the DAQ by sendSamples or stopInactivation

        numSamplesPerChannel % TODO - why is this here? We need a better solution
    end % properties


    properties (Hidden)
        buildFailed = true %Used during boostrap by start_zapit
    end % hidden properties

    properties (Hidden,SetObservable=true)
        lastAcquiredFrame % The last frame acquired by the camera
        calibrateScannersPosData % Used to plot data during scanner calibration
        scannersCalibrated = false % Gets set to true if the scanners are calibrated
        sampleCalibrated = false % Gets set to true if the sample is calibrated
    end


    % read-only properties that are associated with getters
    properties(SetAccess=protected, GetAccess=public)
       imSize
    end


    % Constructor and destructor
    methods
        function obj = pointer(varargin)
            % Constructor
            %
            % Inputs
            % 'simulated' - [false by default] If true does not connect to hardware but 
            %   runs in simulated mode.
            % 'pointsFile' - [empty by default] If provided, should be path to points file for stim

            params = inputParser;
            params.CaseSensitive = false;
            params.addParameter('simulated', false, @(x) islogical(x) || x==0 || x==1);
            params.addParameter('pointsFile', '', @(x) ischar(x));

            params.parse(varargin{:});

            simulated=params.Results.simulated;
            pointsFile=params.Results.pointsFile;

            obj.settings = zapit.settings.readSettings;

            % Connect to camera
            if simulated
                obj.cam = zapit.simulated.camera;
            else
                obj.cam = zapit.hardware.camera(obj.settings.camera.connection_index);
            end
            obj.cam.exposure = obj.settings.camera.default_exposure;

            obj.cam.ROI = [300,100,1400,1000]; % TODO: hardcoded sensor crop
                                            % TODO : in future user will have ROI box to interactively
                                            %    crop and this will be saved in settings file
                                            %    the re-applied on startup each time.
                                            %    see also obj.cam.resetROI

            % Log camera frames to lastAcquiredFrame and start camera
            obj.cam.vid.FramesAcquiredFcn = @obj.storeLastFrame;
            obj.cam.vid.FramesAcquiredFcnCount=1; %Run frame acq fun every N frames
            obj.cam.startVideo;


            if simulated
                obj.DAQ = zapit.simulated.DAQ;
            else
                fprintf('Connecting to DAQ\n')
                obj.DAQ = zapit.hardware.DAQ.NI.vidriowrapper;
            end

            obj.DAQ.parent = obj;

            obj.DAQ.connectUnclockedAO(true)
            
            obj.loadLaserFit
            obj.zeroScanners

            obj.buildFailed = false; % signal to start_zapit that all went well
            return

            % TODO -- this does not have to be here. We can calibrate camera without this. It should be elsewhere. 
            % Load configuration files
            if isempty(pointsFile)
                [pointsFile,fpath] = uigetfile('*.yaml','Pick a config file');
                pathToConfig = fullfile(fpath,pointsFile);
            else
                pathToConfig = pointsFile;
            end
            obj.config = zapit.config(pathToConfig);
        end % Constructor
        
        
        function delete(obj,~,~)
            % Stop the camera and disconnect from hardware
            fprintf('Shutting down optostim software\n')
            obj.cam.vid.FramesAcquiredFcn = [];

            obj.cam.stopVideo;
            delete(obj.cam)
            delete(obj.DAQ)
        end % Destructor
        
    end % end of constructor/destructor block


    % Getters and setters
    methods
        function imSize = get.imSize(obj)
            % Return size of image being acquired by camera
            %
            % iSize = pointer(obj)
            %
            % Purpose
            % Return size of image being acquired by camera. This could change after
            % the camera has been started so it must be handled dynamically.
            imSize = obj.cam.ROI;
            imSize = imSize(3:4);
        end % imsize
    end % getters and setters


    % Other short methods
    methods
        function zeroScanners(obj)
            % TODO -- does it really make sense for galvo control methods to be in the DAQ class?
            % TODO -- running this currently does not update the plot by there are properties
            %         corresponding to these values that we can pick off from the DAQ class.
            obj.DAQ.moveBeamXY([0,0]);
        end % zeroScanners
        
        
        function varargout = runAffineTransform(obj, OUT)
            % TODO - refactor
            % method running a transformation of x-y beam position into pixels
            % in camera
            
            % it can be run repeatedly with each new mouse and it doesn't
            % require scaling from the start (new transformation matrices
            % are added on top of existing ones in function pixelToVolt)
            
            % runs affine transformation
            tform = fitgeotrans(OUT.targetPixelCoords,OUT.actualPixelCoords,'similarity');
            
            obj.transform = tform;

            if nargout>0
                varargout{1} = tform;
            end
        end % runAffineTransform


        function storeLastFrame(obj,~,~)
            % This callback is run every time a frame has been acquired
            %
            %  function zapit.pointer.storeLastFrame(obj,~,~)
            %
            % Purpose
            % Stores the last acquired frame in an observable property

            if obj.cam.vid.FramesAvailable==0
                return
            end

            obj.lastAcquiredFrame = obj.cam.getLastFrame;
            obj.cam.flushdata
        end % storeLastFrame


        function im = returnCurrentFrame(obj,nFrames)
            % Return the last recorded camera image and optionally the last n frames
            %
            % function im = returnCurrentFrame(obj,nFrames)
            %
            % Purpose
            % Return the last frame and, if requested, the last n frames.
            %
            % Inputs
            % nFrames - [optional] 1 by default. If >1 this many frames are returned.
            %
            % Outputs
            % im - the image
            %
            %

            % TODO -- this is really slow right now if nFrames > 1 (since refactoring 21/12/2022)
            if nargin<2
                nFrames = 1;
            end

            im = obj.lastAcquiredFrame;

            if nFrames==1
                return
            end

            im = repmat(im,[1,1,nFrames]);
            lastFrameAcquired = obj.cam.vid.FramesAcquired; % The frame number

            indexToInsertFrameInto = 2;
            while indexToInsertFrameInto < nFrames
                % If statment adds a new frame once the counter of number of frames
                % has incrememted
                currentFramesAcquired = obj.cam.vid.FramesAcquired;
                if currentFramesAcquired > lastFrameAcquired
                    im(:,:,indexToInsertFrameInto) = obj.lastAcquiredFrame;
                    lastFrameAcquired = currentFramesAcquired;
                    indexToInsertFrameInto = indexToInsertFrameInto +1;
                end
            end
        end % returnCurrentFrame


    end % methods

end % classdef
