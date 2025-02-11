classdef (Abstract) settingsValuesTests

    % Tests associated with default_settings
    %
    % zapit.settings.settingsValuesTests
    %
    % Purpose
    % Defines generic tests that can be combined to ensure values in settings file reasonable.
    %
    %
    % See zapit.settings.checkSettingsAreValid for how these methods are used.
    % See zapit.settings.default_settings for where tests are specified.
    %
    %
    % Rob Campbell - SWC 2023


    %%
    % The following methods apply checks and replace bad values with defaults.
    methods(Static)

        % * How the folowing methods work
        % In each case the following methods test some aspect of value in the structure "actualStruct".
        % The value itself is always addressed as "actualStruct.(sectionName).fieldName". This is done
        % in the function "zapit.settings.checkSettingsAreValid". If the value does not pass then the
        % default value from the structure "defaultStruct" is used to replace the value that was present.
        % A message is displayed to the CLI. The second output argument of each method, "isValid" is
        % true if no replacement had to be done and false otherwise. This is used by the function
        % "zapit.settings.checkSettingsAreValid" to determine whether any settings in the YAML at all
        % needed replacing.

        function [actualStruct,isValid] = check_isnumeric(actualStruct,defaultStruct,sectionName,fieldName)
            isValid = true;
            if ~isnumeric(actualStruct.(sectionName).(fieldName))
                fprintf('-> %s.%s should be a number. Setting it to %d.\n', ...
                    sectionName,fieldName,defaultStruct.(sectionName).(fieldName))
                actualStruct.(sectionName).(fieldName) = defaultStruct.(sectionName).(fieldName);
                isValid = false;
            end
        end


        function [actualStruct,isValid] = check_ischar(actualStruct,defaultStruct,sectionName,fieldName)
            isValid = true;
            if ~ischar(actualStruct.(sectionName).(fieldName))
                fprintf('-> %s.%s should be a scalar. Setting it to %s.\n', ...
                    sectionName,fieldName,defaultStruct.(sectionName).(fieldName))
                actualStruct.(sectionName).(fieldName) = defaultStruct.(sectionName).(fieldName);
                isValid = false;
            end
        end


        function [actualStruct,isValid] = check_isscalar(actualStruct,defaultStruct,sectionName,fieldName)
            isValid = true;
            if ~isnumeric(actualStruct.(sectionName).(fieldName)) || ...
                 ~isscalar(actualStruct.(sectionName).(fieldName))
                fprintf('-> %s.%s should be a scalar. Setting it to %d.\n', ...
                    sectionName,fieldName,defaultStruct.(sectionName).(fieldName))
                actualStruct.(sectionName).(fieldName) = defaultStruct.(sectionName).(fieldName);
                isValid = false;
            end
        end


        function [actualStruct,isValid] = check_isZeroOrGreaterScalar(actualStruct,defaultStruct,sectionName,fieldName)
            isValid = true;
            if ~isnumeric(actualStruct.(sectionName).(fieldName)) || ...
                ~isscalar(actualStruct.(sectionName).(fieldName)) || ...
                    actualStruct.(sectionName).(fieldName)<0
                fprintf('-> %s.%s should be a number. Setting it to %d.\n', ...
                    sectionName,fieldName,defaultStruct.(sectionName).(fieldName))
                actualStruct.(sectionName).(fieldName) = defaultStruct.(sectionName).(fieldName);
                isValid = false;
            end
        end


        function [actualStruct,isValid] = check_isLogicalScalar(actualStruct,defaultStruct,sectionName,fieldName)
            isValid = true;
            if ~isscalar(actualStruct.(sectionName).(fieldName)) || ...
                (actualStruct.(sectionName).(fieldName) ~= 0 && ...
                actualStruct.(sectionName).(fieldName) ~= 1)
                fprintf('-> %s.%s should be a logical scalar. Setting it to %d.\n', ...
                    sectionName,fieldName,defaultStruct.(sectionName).(fieldName))
                actualStruct.(sectionName).(fieldName) = defaultStruct.(sectionName).(fieldName);
                isValid = false;
            end
        end
    end % check methods


    %%
    % The following methods perform conversions or other house-keeping tasks, not checks
    methods(Static)

        function [actualStruct,isValid] = convert_cell2mat(actualStruct,~,sectionName,fieldName)
            % Used to turn a cell array into a matrix. This is because arrays from a YAMLs are read in as
            % cell arrays and sometimes they need to be matrices. This method is called in
            % zapit.settings.checkSettingsAreValid and we select when it is to be run by defining this in
            % zapit.settings.default_settings
            isValid = true;
            actualStruct.(sectionName).(fieldName) = cell2mat(actualStruct.(sectionName).(fieldName));
        end

    end % Methods

end % classdef
