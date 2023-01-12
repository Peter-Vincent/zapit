function highlightArea_Callback(obj,~,~)
    % Highlight the brain area under the mouse cursor
    %
    % zapit.gui.stimConfigEditor.controller.highlightArea_Callback
    %
    % Purpose
    % This callback highlights the brain area under the mouse cursor.


     % For ease
    brain_areas = obj.atlasData.dorsal_brain_areas;

    C = get (obj.hAx, 'CurrentPoint');
    X = C(1,1);
    Y = C(1,2);

    % Set the current point to follow the mouse
    if obj.BilateralButton.Value == 1
        obj.pCurrentPoint.XData = [-X,X];
        obj.pCurrentPoint.YData = [Y,Y];
    else
        obj.pCurrentPoint.XData = X;
        obj.pCurrentPoint.YData = Y;
    end


    % If shift is pressed we highlight points nearest the cursor and alter the current point shape
    set([obj.pAddedPoints],'MarkerSize', 14)
    if obj.isShiftPressed && length(obj.pAddedPoints)>0
        % We are in delete mode
        obj.pCurrentPoint.MarkerSize = 20;
        obj.pCurrentPoint.Marker = 'x';
        obj.pCurrentPoint.Color = 'r';
        ind = obj.findIndexOfAddedPointNearestCursor;
        obj.pAddedPoints(ind).MarkerSize=20;
    else
        % To reflect the next symbol
        obj.pCurrentPoint.Marker = obj.currentSymbol;
        obj.pCurrentPoint.Color = obj.currentColor;
        obj.pCurrentPoint.MarkerSize = 14; % TODO -- hardcoded
    end

    % Find brain area index
    [~,indX] = min(abs(obj.atlasData.top_down_annotation.xData-X));
    [~,indY] = min(abs(obj.atlasData.top_down_annotation.yData-Y));
    t_ind = obj.atlasData.top_down_annotation.data(indY,indX);
    f = find([brain_areas.area_index]==t_ind);

    delete(findall(obj.hAx,'type','patch'))

    if isempty(f)
        area_name = '';
        obj.hFig.Pointer = 'arrow'; % Return pointer to arrow when it's out of brain
        obj.pMLtick.Visible = 'off';
        obj.pAPtick.Visible = 'off';
    else
        area_name = [', ',brain_areas(f).names{1}];
        b = brain_areas(f).boundaries_stereotax;

        if X<0 || length(b)==1
            b = b{1};
        else
            b = b{2};
        end

        p = patch(b(:,2), b(:,1),1, 'FaceAlpha', 0.1, ...
                'FaceColor', 'r', 'EdgeColor', 'r', ...
                'Parent', obj.hAx);

        obj.hFig.Pointer = 'arrow'; %Can change the pointer when it's in the brain if we want
        obj.pMLtick.XData = [X,X];
        obj.pAPtick.YData = [Y,Y];
        obj.pMLtick.Visible = 'on';
        obj.pAPtick.Visible = 'on';
    end

    % TODO -- the following line does nothing right now
    obj.hAxTitle.String = sprintf('ML=%0.2f mm, AP=%0.2f mm%s\n', X, Y, area_name);
end
