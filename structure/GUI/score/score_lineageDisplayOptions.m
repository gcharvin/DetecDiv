function options = score_lineageDisplayOptions(app)
%SCORE_LINEAGEDISPLAYOPTIONS Read the exclusive lineage UI and link colors.

options = struct( ...
    'mode', 'none', ...
    'showBudPairing', false, ...
    'showGenealogy', false, ...
    'budLinkColor', [1 0.8196 0.051], ...
    'genealogyLinkColor', [0.051 0.749 1]);

try
    if isprop(app, 'LineageDisplayButtonGroup') && ...
            ~isempty(app.LineageDisplayButtonGroup) && isvalid(app.LineageDisplayButtonGroup)
        selected = app.LineageDisplayButtonGroup.SelectedObject;
        if isequal(selected, app.BudLinksRadioButton)
            options.mode = 'bud';
            options.showBudPairing = true;
        elseif isequal(selected, app.FullGenealogyRadioButton)
            options.mode = 'genealogy';
            options.showGenealogy = true;
        end
    else
        % Compatibility with layouts saved before the radio-button group.
        if isprop(app, 'DisplayBudPairingCheckBox') && isvalid(app.DisplayBudPairingCheckBox)
            options.showBudPairing = logical(app.DisplayBudPairingCheckBox.Value);
        end
        if isprop(app, 'DisplayLineageCheckBox') && isvalid(app.DisplayLineageCheckBox)
            options.showGenealogy = logical(app.DisplayLineageCheckBox.Value);
        end
        if options.showGenealogy
            options.mode = 'genealogy';
        elseif options.showBudPairing
            options.mode = 'bud';
        end
    end
    if isprop(app, 'BudlinkcolorColorPicker') && isvalid(app.BudlinkcolorColorPicker)
        options.budLinkColor = double(app.BudlinkcolorColorPicker.Value);
    end
    if isprop(app, 'GenealogyLinkColorPicker') && isvalid(app.GenealogyLinkColorPicker)
        options.genealogyLinkColor = double(app.GenealogyLinkColorPicker.Value);
    end
catch
end
end
