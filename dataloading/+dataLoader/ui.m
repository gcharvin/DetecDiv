function ctx = ui(ctx)
% dataLoader.ui  Launch addDataGUI for interactive setup.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if ~isfield(ctx,'shallow') || isempty(ctx.shallow)
        ctx.shallow = shallow();
    end

    app = addDataGUI(ctx.shallow, []);
    try
        waitfor(app.UIFigure);
    catch
    end

    % Data should already be added to ctx.shallow by the GUI
    ctx.fovList = ctx.shallow.fov;
end
