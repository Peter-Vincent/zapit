function [settings,settingsNonHardCoded] = readSettings
    % Read Zapit settings from SETTINGS/settings.yml 
    %
    % function settings = zapit.settings.readSettings
    %
    %
    % Purpose
    % This function parses SETTINGS/settings.yml and creates it if does not already exist.
    %
    % If no settings have been created then a default settings file is created. The user is 
    % prompted to edit it and nothing is returned. If a settings file is present and looks 
    % identical to the default one, the user is prompted to edit it and nothing is returned. 
    % Otherwise the settings file is read and returned as a structure. 
    %
    %
    % Rob Campbell - Basel 2017

    settings=[];


    [settingsDir,backupSetingsDir] = zapit.settings.settingsLocation;


    settingsFname = 'systemSettings.yml';
    settingsFile = fullfile(settingsDir,settingsFname);

    DEFAULT_SETTINGS = default_BT_Settings;
    if ~exist(settingsFile)
        fprintf('Can not find system settings file: making default file at %s\n', settingsFile)
        zapit.yaml.WriteYaml(settingsFile,DEFAULT_SETTINGS);
    end



    settings = zapit.yaml.ReadYaml(settingsFile);

    %Check if the loaded settings are the same as the default settings
    if isequal(settings,DEFAULT_SETTINGS)
        fprintf('\n\n *** The settings file at %s has never been edited\n *** Press RETURN then edit the file for your system.\n', settingsFile)
        fprintf(' *** For help editing the file see: https://github.com/BaselLaserMouse/BakingTray/wiki/The-Settings-Files\n\n')
        pause
        edit(settingsFile)
        fprintf('\n\n *** Once you have finished editing the file, save it and press RETURN\n')

        pause
        settings = zapit.settings.readSettings;
        return
    end


    % Pull in values from the default settings that are missing in the user settings file.
    f0 = fields(DEFAULT_SETTINGS);
    addedDefaultValue = false;
    for ii = 1:length(f0);
        f1 = fields(DEFAULT_SETTINGS.(f0{ii}));

        % Create missing structure if necessary (unlikely to ever be the case)
        if ~isfield(settings,f0{ii});
            settings.(f0{ii}) = [];
        end

        for jj = 1:length(f1)
            if ~isfield(settings.(f0{ii}), f1{jj})
                addedDefaultValue = true;
                fprintf('\n\n Adding missing default setting "%s.%s" from default_BT_Settings.m\n', ...
                    (f0{ii}), f1{jj})
                settings.(f0{ii}).(f1{jj}) = DEFAULT_SETTINGS.(f0{ii}).(f1{jj});
            end
        end
    end



    % Make sure all settings that are returned are valid
    % If they are not, we replace them with the original default value

    allValid=true;

    if ~ischar(settings.NI.device_ID)
        fprintf('NI.device_ID should be a string. Setting it to "%s"\n', DEFAULT_SETTINGS.SYSTEM.ID)
        settings.NI.device_ID = DEFAULT_SETTINGS.SNI.device_ID;
        allValid=false;
    end


    if ~isnumeric(settings.camera.connection_index)
        fprintf('camera.connection_index should be a number. Setting it to %d \n', DEFAULT_SETTINGS.camera.connection_index)
        settings.camera.connection_index = DEFAULT_SETTINGS.camera.connection_index;
        allValid=false;
    elseif settings.camera.connection_index<=0
        fprintf('Scamera.connection_index should be >0. Setting it to %d \n',DEFAULT_SETTINGS.camera.connection_index)
        settings.camera.connection_index = DEFAULT_SETTINGS.camera.connection_index;
        allValid=false;
    end


    if ~isnumeric(settings.camera.default_exposure)
        fprintf('camera.default_exposure should be a number. Setting it to %d \n', DEFAULT_SETTINGS.camera.default_exposure)
        settings.camera.default_exposure = DEFAULT_SETTINGS.camera.default_exposure;
        allValid=false;
    end


    if ~isnumeric(settings.camera.beam_calib_exposure)
        fprintf('camera.beam_calib_exposure should be a number. Setting it to %d \n', DEFAULT_SETTINGS.camera.beam_calib_exposure)
        settings.camera.beam_calib_exposure = DEFAULT_SETTINGS.camera.beam_calib_exposure;
        allValid=false;
    end




    if ~allValid
        fprintf('\n ********************************************************************\n')
        fprintf(' * YOU HAVE INVALID VALUES IN %s (see above). \n', settingsFile)
        fprintf(' * They have been replaced with valid defaults. \n')
        fprintf(' **********************************************************************\n')
    end



    % If there are missing or invalid values we will replace these in the settings file as well as making
    % a backup copy of the original file.
    if ~allValid || addedDefaultValue
       % Copy file
       backupFname = fullfile(backupSetingsDir, [datestr(now, 'yyyy_mm_dd__HH_MM_SS_'),settingsFname]);
       fprintf('Making backup of settings file at %s\n', backupFname)
       copyfile(settingsFile,backupFname)

       % Write the new file to the settings location
       fprintf('Replacing settings file with updated version\n')
       zapit.yaml.WriteYaml(settingsFile,settings);
    end


    settingsNonHardCoded=settings;


    % Git info will make up the version information
    g=zapit.utils.getGitInfo;
    systemVersion = sprintf('branch=%s  commit=%s', g.branch, g.hash);
    settings.zapit.version=systemVersion;
