function controlVal = laser_mW_to_control(obj,mW)
    % Convert a desired value in mW to a control voltage for the laser
    % 
    % function controlVal = zapit.pointer.laser_mW_to_control(mW)
    %
    % Purpose
    % The user will request a laser power in mW at the sample. A calibration
    % curve is generated by zapit.pointer.generateLaserCalibrationCurve and
    % this method uses this curve to convert the requested nW value to the 
    % equivilant control voltage. If there is no laser fit, a linear estimate
    % is made. This will be very accurate if you have done through the steps
    % described in the user guide.
    %
    %
    % Inputs
    % mW - requested value in mW
    %
    % Outputs
    % controlVal - the control voltage that will produce the requested mW value. 
    %
    % 
    % Rob Campbell - SWC 2022
    %
    % See also: 
    % zapit.pointer.setLaserInMW
    % zapit.pointer.generateLaserCalibrationCurve



    % Make local copies of setting needed in multiple places below
    minPower = obj.settings.laser.laserMinMax_mW(1);
    maxPower = obj.settings.laser.laserMinMax_mW(2);
    maxCV = obj.settings.laser.laserMinMaxControlVolts(2);

    if isempty(obj.laserFit) || useLinear
        % The laser fit is only needed if the laser is not linear. Since so far only very cheap
        % lasers have been found to be non-linear we can not make a fuss if the fit is missing and
        % just assume it is linear.

        controlVal = (mW/maxPower) * maxCV - minPower ;
    else
        %Otherwise we handle the case where the user has a control curve

        % Re-scale the sensor values so they are in mW
        mWvals = obj.laserFit.sensorValues;
        mWvals = mWvals - min(mWvals);
        mWvals = mWvals / max(mWvals);

        % TODO -- for now let us just assume that it starts at zero
        mWvals = mWvals * maxPower;

        % Make a plolynomial fit of the sensory values convert to mW as a function of the laser control value
        % The is the correct way of doing the fit but it won't directly give us the answer we want, as we wish
        % to know the control value that produces a given mW value.
        laserFit_ControlToMW = fit(obj.laserFit.controlValues,mWvals,'poly3');

        % Therefore we solve the problem by finding the closest value to our desired value
        contV = linspace(obj.laserFit.controlValues(1),obj.laserFit.controlValues(end),10000);
        mwV = laserFit_ControlToMW(contV);

        % TODO -- need to interpolate. We currently get quantization if calibration was
        % against the full scale.
        [~,ind] = min(abs(mwV-mW));

        controlVal = contV(ind(1)); % take the first if there are multiple

    end

    % Make sure the control value is not out of bounds
    if controlVal>maxCV
        fprintf('Requested value of %0.2f mW is out of range. Capping at laser max power of %0.2f mW\n',...
            mW, maxPower)
        controlVal = maxCV;
    end


end % laser_mW_to_control
