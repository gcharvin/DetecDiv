function [displayHandles, layoutOptions] = score_createDisplayHandles(layoutOptions,hfig)
% createDisplayHandles Crée un master tiledlayout pour l'affichage sans uipanel.
%
% Pour 'sequence' :
%    ROI_rows = (si overlay true : Nbrick + Ndataseries,
%                sinon : Nchannel * Nbrick + Ndataseries)
%    ROI_cols = Nframes * Nbrick
%    MasterRows = Nrow * ROI_rows, MasterCols = Ncol * ROI_cols
%
% Pour 'display' :
%    MasterRows = Nbrick + Ndataseries, MasterCols = Nchannel * Nbrick.
%
% Pour 'movie' :
%    MasterRows = Nrow * (Nbrick + Ndataseries), MasterCols = Ncol * (Nchannel * Nbrick).
%
% Le master tiledlayout est créé avec 'TileSpacing' et 'Padding' réglés sur 'none'.

margin = 5;
extraMargin = 50;

background=layoutOptions.background

%layoutOptions.Nbrick=2;

%% build layout
    switch lower(layoutOptions.mode)
        case 'sequence'
            if layoutOptions.overlay
                ROI_rows = layoutOptions.Nbrick + layoutOptions.Ndataseries;
            else
                ROI_rows = layoutOptions.Nchannel * layoutOptions.Nbrick + layoutOptions.Ndataseries;
            end

            ROI_cols = numel(layoutOptions.frames) * layoutOptions.Nbrick;
            MasterRows = layoutOptions.Nrow * ROI_rows;
            MasterCols = layoutOptions.Ncol * ROI_cols;

            figWidth = MasterCols * layoutOptions.tileW + (MasterCols+1)*margin;
            figHeight = MasterRows * layoutOptions.tileH + (MasterRows+1)*margin + extraMargin;

            fig = figure('Name', 'Sequences Export (Vectorial)', 'Units', 'pixels', ...
    'Position', [100, 100, figWidth, figHeight]);
set(fig, 'Color', background);

            masterTL = tiledlayout(fig, MasterRows, MasterCols, 'TileSpacing', 'none', 'Padding', 'none');
            displayHandles.masterTiledLayout = masterTL;
            displayHandles.MasterRows = MasterRows;
            displayHandles.MasterCols = MasterCols;
            displayHandles.ROI_rows = ROI_rows;
            displayHandles.ROI_cols = ROI_cols;
            displayHandles.mode = 'sequence';
        case 'display'
            % Pour display, une seule ROI est utilisée.
              if layoutOptions.overlay
                ROI_rows = layoutOptions.Nbrick + layoutOptions.Ndataseries;
                ROI_cols = layoutOptions.Nbrick;
            else
                ROI_rows = layoutOptions.Nbrick + layoutOptions.Ndataseries;
                ROI_cols = layoutOptions.Nchannel * layoutOptions.Nbrick;
            end

            %ROI_rows = layoutOptions.Nbrick + layoutOptions.Ndataseries;
            %ROI_cols = layoutOptions.Nchannel * layoutOptions.Nbrick

             figWidth = ROI_cols  * layoutOptions.tileW + (ROI_cols +1)*margin;
            figHeight = ROI_rows * layoutOptions.tileH + (ROI_rows+1)*margin + extraMargin;

            if nargin==2  && ~isempty(hfig) && ishandle(hfig) && isvalid(hfig)
            fig=hfig;
         %   set(fig,'Name', 'Sequences Export (Vectorial)', 'Units', 'pixels', ...
  %  'Position', [100, 100, figWidth, figHeight]);
            set(fig, 'Color', background);
            clf;
            else
            fig= figure('Name', 'Sequences Export (Vectorial)', 'Units', 'pixels', ...
    'Position', [100, 100, figWidth, figHeight]);
set(fig, 'Color', background);
            end

            masterTL = tiledlayout(fig, ROI_rows, ROI_cols, 'TileSpacing', 'none', 'Padding', 'none');
            displayHandles.masterTiledLayout = masterTL;
            displayHandles.MasterRows = ROI_rows;
            displayHandles.MasterCols = ROI_cols;
            displayHandles.mode = 'display';

        case 'movie'
            % Pour movie, plusieurs ROI sont affichées, mais le layout interne de chaque ROI
            % est identique à celui du mode display.
               if layoutOptions.overlay
                ROI_rows = layoutOptions.Nbrick + layoutOptions.Ndataseries;
                ROI_cols = layoutOptions.Nbrick;
            else
                ROI_rows = layoutOptions.Nbrick + layoutOptions.Ndataseries;
                ROI_cols = layoutOptions.Nchannel * layoutOptions.Nbrick;
            end

            MasterRows = layoutOptions.Nrow * ROI_rows;
            MasterCols = layoutOptions.Ncol * ROI_cols;

              figWidth = MasterCols * layoutOptions.tileW + (MasterCols+1)*margin;
            figHeight = MasterRows * layoutOptions.tileH + (MasterRows+1)*margin + extraMargin;

            fig = figure('Name', 'Sequences Export (Vectorial)', 'Units', 'pixels', ...
    'Position', [100, 100, figWidth, figHeight]);
set(fig, 'Color', background);

            masterTL = tiledlayout(fig, MasterRows, MasterCols, 'TileSpacing', 'none', 'Padding', 'none');
            displayHandles.masterTiledLayout = masterTL;
            displayHandles.MasterRows = MasterRows;
            displayHandles.MasterCols = MasterCols;
            displayHandles.ROI_rows = ROI_rows;
            displayHandles.ROI_cols = ROI_cols;
            displayHandles.mode = 'movie';
            
    end

    displayHandles.Figure=fig;

