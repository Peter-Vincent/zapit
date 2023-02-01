function settings = default_settings
    % Return a set of default system settings to write to a file in the settings directory
    %
    % settings = default_settings

    settings.general.maxSettingsBackUpFiles = 50;
    settings.general.openPythonBridgeOnStartup = 0;

    settings.NI.device_ID = 'Dev1';
    settings.NI.samplesPerSecond = 10000;
    settings.NI.triggerChannel = 'PFI0';
    settings.NI.wrapper = 'dotnet'; % 'vidrio' or 'dotnet'

    settings.scanners.voltsPerPixel = 2.2E-3;
    settings.scanners.invertXscanner = 0;
    settings.scanners.invertYscanner = 0;

    settings.laser.name = 'obis';
    settings.laser.laserMinMaxControlVolts = [1.5,3.5];
    settings.laser.laserMinMax_mW = [0,100];
    settings.laser.maxValueInGUI = 20; %TODO not in validation script

    settings.camera.default_exposure = 2000;
    settings.camera.micronsPerPixel = 19.3;
    settings.camera.flipImageUD = 0;
    settings.camera.flipImageLR = 0;

    settings.calibrateScanners.areaThreshold = 500;
    settings.calibrateScanners.calibration_power_mW = 10;
    settings.calibrateScanners.beam_calib_exposure = 2000;
    settings.calibrateScanners.bufferMM = 2;
    settings.calibrateScanners.pointSpacingInMM = 3;

    settings.calibrateSample.refAP = 3;

    settings.experiment.defaultLaserFrequencyHz = 40; 
    settings.experiment.defaultLaserPowerMW = 5;
    settings.experiment.offRampDownDuration_ms = 250;
    settings.experiment.maxStimPointsPerCondition = 2;

    settings.cache.ROI = [];
    settings.cache.previouslyLoadedFiles = [];

end % default_settings
