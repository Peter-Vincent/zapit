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
        flipXY % TODO -- should add this but only once everything else is working
        voltsPerPixel = 2.2E-3 %TODO -- HARDCODED
        micsPix = 19.3 %Measured this %TODO -- HARDCODED
        
        % Properties related to where we stimulate
        transform
        config % Object of class zapit.config

        
        % behavioural task properties
        coordsLibrary % TODO - I think this is where all computed waveforms are kept
        newpoint % TODO - ??
        topUpCall % TODO - ??
        rampDown % Not used (yet?)
        chanSamples %Structure describing waveforms to send the scanners for each brain area
        freqLaser % TODO - ??
        numSamplesPerChannel % TODO - why is this here? We need a better solution
        sampleRate % TODO - This is now elsewhere but keep for the moment

        DAQ % instance of class that controls the DAQ will be attached here
    end % properties


    properties (Hidden)
        % Handles for plot elements
        hFig
        hImAx
        hImLive
        hLastPoint % plot handle with location of the last clicked point

        hAreaCoords % locations where the beam will be sent. see getAreaCoords
        hRefCoords  % The two reference coords

        axRange

        % Camera and image related
        cam % camera object goes here

    end % hidden properties

    % read-only properties that are associated with getters
    properties(SetAccess=protected, GetAccess=public)
       imSize
    end
    
    % Constructor and destructor
    methods
        function obj = pointer(fname)
            % Constructor

            if nargin < 1
                fname = [];
            end

            disp('STARTING BEAMPOINTER')

            % Connect to camera
            obj.cam = zapit.camera(2); % TODO -  Hard-coded selection of camera ID
            obj.cam.exposure = 3000; % TODO - HARDCODED
            obj.cam.ROI = [300,100,1400,1000]; % TODO: hardcoded sensor crop
                                            % TODO : in future user will have ROI box to interactively
                                            %    crop and this will be saved in settings file
                                            %    the re-applied on startup each time.
                                            %    see also obj.can.resetROI

            obj.setUpFigure

            % Attach the DAQ (TODO: for now we hard-code the class as it's the only one)
            obj.DAQ = zapit.hardware.DAQ.NI.vidriowrapper;
            obj.DAQ.parent = obj;

            % TODO - Put connection to DAQ in a method
            obj.DAQ.connectUnclocked(true)
            
            
            % TODO -- we should presumbably implement the following again?
            % When window closes we disconnect from the DAQ
            % obj.hFig.CloseRequestFcn = @obj.figClose;
            
            obj.zeroScanners

            % TODO -- we evenually want to be setting laser power in mW with a laser class.
            % so we will need the laser class to talk to the DAQ. Therefore it might make
            % sense to have a scanner class that talks to the DAQ (see above)
            obj.DAQ.setLaserPowerControlVoltage(1) % TODO -- we will need

            % load configuration files
            if isempty(fname)
                [fname,fpath] = uigetfile('*.yaml','Pick a config file');
                pathToConfig = fullfile(fpath,fname);
            else
                pathToConfig = fname;
            end
            obj.config = zapit.config(pathToConfig);
        end % Constructor
        
        
        
        function delete(obj,~,~)
            fprintf('Shutting down optostim software\n')
            obj.cam.stopVideo;
            delete(obj.hFig)
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

            if nargin<2
                nFrames = 1;
            end

            im = obj.hImLive.CData;

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
                    im(:,:,indexToInsertFrameInto) = obj.hImLive.CData;
                    lastFrameAcquired = currentFramesAcquired;
                    indexToInsertFrameInto = indexToInsertFrameInto +1;
                end
            end
        end % returnCurrentFrame


        function sendSamples(obj, new_trial, verbose)
            % take coordinates of two points[x and y Coords], and exchange laser between
            % them at freqLaser for pulseDuration seconds, locking it at a given point for tOpen ms
            % inputs: obj.chanSamples,
            %         CoordNum,
            %         LaserOn
            %         powerOption - if 1 send 2 mW, if 2 send 4 mW (mean)
            % output: nothing. The function just sends correct samples to
            % the pointer

            if nargin<3
                verbose = false;
            end

            CoordNum = new_trial.area;
            LaserOn = new_trial.LaserOn;
            trialPower = new_trial.powerOption;

            if verbose
                fprintf('Stimulating area %d\n', CoordNum)
            end

            if ~strcmp(obj.DAQ.hC.taskName, 'clocked'); % TODO-- maybe this check should be in the
                                                        % the createNewTask. So we don't make unless
                                                        % the task names don't match?
                obj.DAQ.connectClocked;
            end
            
            % update coordinate parameters/channel samples
            voltChannel(:,1:2) = obj.chanSamples.scan(:,:,CoordNum);
            voltChannel(:,3:4) = trialPower * obj.chanSamples.light(:,[3 2],LaserOn+1);  % if laseron = 0, no inactivation
            % for now, I exchanged the analog output 1 with the digital 3
            % so that we have a square waveform (until we figure out how to
            % get higher output wattage from obis laser)
            
            % write voltage samples onto the task
            obj.DAQ.hC.writeAnalogData(voltChannel);

            % start the execution of the new task
            obj.DAQ.start;

        end % sendSamples
        
        
        function stopInactivation(obj)
            % called at the end of a trial
            % send 0 Volts if sample generation has already been triggered
            % and stops task
            
            % TODO -- this method we will change to allow for the ramp-down
            try
                % try-end used because overwriting buffer before trigger
                % comes (e.g. run abort before inactivation) may throw errors
                
                voltChannel(:,1:2) = obj.chanSamples.light(:,[1 1],1); % just zeros
                voltChannel(:,3:4) = obj.chanSamples.light(:,[1 1],1); % just zeros
                
                obj.DAQ.hC.writeAnalogData(voltChannel);
                
                % pause to wait for 0s to be updated in the buffer and
                % generated before closing
                pause(1);
            end
            
            % stop task and send to pre-generation stage, allowing to write
            % next trial samples without conflicts
            obj.DAQ.hC.abort
        end % stopInactivation
        
        
        function [xVolts, yVolts] = pixelToVolt(obj, pixelColumn, pixelRow)
            % Converts pixel position to voltage value to send to scanners
            %
            % function [xVolts, yVolts] = pixelToVolt(obj, pixelColumn, pixelRow)
            %
            % Purpose
            % Converts pixel coordinates to volt values for scanner mirrors
            % taking into account created transformation matrices (infinite
            % number of those allowed).
            %
            % This function is important and used every time the laser is
            % pointed to a location. Called in: pointBeamToLocationInImage,
            % getAreaCoordinates and logPoints
            %
            %
            % Inputs
            % Pixel row and column


            if ~isempty(obj.transform)
                [pixelColumn, pixelRow] = transformPointsInverse(obj.transform, pixelColumn, pixelRow);
            end
            
            
            xVolts = (pixelColumn - (obj.imSize(1)/2)) * obj.voltsPerPixel;
            yVolts = (pixelRow    - (obj.imSize(2)/2)) * obj.voltsPerPixel;
            
            if obj.invertX
                xVolts = xVolts*-1;
            end

            if obj.invertY
                yVolts= yVolts*-1;
            end
        end % pixelToVolt
        
        
        function dispFrame(obj,~,~)
            % This callback is run every time a frame has been acquired
            if obj.cam.vid.FramesAvailable==0
                return
            end
            
            tmp = obj.cam.getLastFrame;
            
            obj.hImLive.CData = tmp;
            drawnow
            obj.cam.flushdata
        end % dispFrame


    end % methods

end % classdef
