function varargout = start_zapit(varargin)
    % Creates a instance of the zapit pointer class and places it in the base workspace as hZP
    %
    % function start_zapit(varargin)
    %
    % Purpose
    % Zapit startup function. Starts software if it is not already started.
    %
    %
    % Optional Input args (param/val pairs
    % 'simulated'  -  [False by default on Windows. True on Linux and Mac] If true does not connect 
    %                to hardware but runs in  simulated mode.
    % 'useExisting'  -  [False by default] If true, an exsiting instance of hZP is used.
    % 'startGUI'  -  [True by default]
    %
    %
    % Outputs
    % The outputs are optional. These variables are automatically created in the
    % base workspace and don't need to be explicitly placed there.
    %
    % hZP - instance of class zapit.pointer 
    % hZPview - instance of class zapit.gui.main.controller
    %
    % Rob Campbell - SWC 2022

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    %Parse optional arguments
    params = inputParser;
    params.CaseSensitive = false;
    if isunix
        defaultSimulated = true;
    else
        defaultSimulated = false;
    end
    params.addParameter('simulated', defaultSimulated, @(x) islogical(x) || x==0 || x==1);
    params.addParameter('useExisting', false, @(x) islogical(x) || x==0 || x==1);
    params.addParameter('startGUI', true, @(x) islogical(x) || x==0 || x==1);

    params.parse(varargin{:});

    useExisting=params.Results.useExisting;
    simulated=params.Results.simulated;
    startGUI=params.Results.startGUI;

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

    % Build optional arguments to feed to Zapit during its construction
    ZPargs={'simulated',simulated};


    %Does a Zapit object exist in the base workspace?
    evalin('base','clear ans') %Because it sometimes makes a copy of BT in ans when it fails
    hZP = zapit.utils.getObject(true);

    if isempty(hZP)


        % If the user has requested the Python bridge we attempt to connect and bail
        % out if this fails. A message will be produced by the connection function.
        settings = zapit.settings.readSettings;
        if settings.general.openPythonBridgeOnStartup
            if ~zapit.utils.openPythonBridge
                return
            else
                fprintf('Opened Python Bridge\n')
            end
        end

        %If not, we build hZP and place it in the base workspace
        try
            if simulated
                fprintf('Running Zapit in simulated mode\n')
            end

            hZP = zapit.pointer(ZPargs{:});

            % Place the object in the base workspace as a variable called "hZP"
            assignin('base','hZP',hZP);
        catch ME
            fprintf('Build of hZP failed\n')
            delete(hZP) % Avoids blocked hardware controllers
            evalin('base','clear ans') % Because it sometimes makes a copy of ZP in ans when it fails
            rethrow(ME)
        end

    else
        %If it does exist, we only re-use it if the user explicitly asked for this and there
        if useExisting
            assignin('base','hZP',hZP);
        else
            fprintf('Zapit seems to already be started.\n')
            return
        end

    end %if isempty(hZP)


    if hZP.buildFailed
        fprintf('%s failed to create an instance of zapit pointer. Quitting.\n', mfilename)
        hZP.delete
        evalin('base','clear hZP')
        return
    end %if hZP.buildFailed


    %By this point we should have a functioning hZP object, which is the model in our model/view system

 


    % Report where Zapit is installed
    fprintf('Zapit is installed at %s\n', zapit.updater.getInstallPath)

    % Now we make the view
    if startGUI
        fprintf('Building GUI\n')
        hZPview = zapit.gui.main.controller(hZP);
        assignin('base','hZPview',hZPview);
    else
        hZPview = [];
    end

    fprintf('Zapit has started\n')

    % Report whether zapit is up to date using GitHub releases
    details = zapit.updater.checkForNewVersion;
    if ~isempty(details)
        if details.isUpToDate
            fprintf(details.msg)
            zapit.version
        else
            fprintf('\n\n%s\n',details.msg)
            disp('For upgrading instructions see <a href="https://github.com/BaselLaserMouse/zapit/blob/main/README.md">the README</a>.')
            fprintf('\n\n')
        end
    end

    if nargout>0
        varargout{1} = hZP;
    end

    if nargout>1
        varargout{2} = hZPview;
    end

%-------------------------------------------------------------------------------------------------------------------------
function safe = isSafeToMake_hZP
    % Return true if it's safe to copy the created BT object to a variable called "hZP" in
    % the base workspace. Return false if not safe because the variable already exists.

    W=evalin('base','whos');

    if strmatch('hZP',{W.name})
        fprintf('Zapit seems to have already started. If this is an error, remove the variable called "hZP" in the base workspace.\n')
        fprintf('Then run "%s" again.\n',mfilename)
        safe=false;
    else
        safe=true;
    end

    
