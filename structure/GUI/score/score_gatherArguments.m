function arg=score_gatherArguments(app,selectedROI)
% for display mode

currentFrame = selectedROI.display.frame;

% Construction de la liste d'arguments pour display
arg = {};

% --- Paramètres liés au movie ---
% 'Frames' : conversion de la chaîne (ex. '1:10') en tableau numérique
arg = [arg, {'frames', currentFrame}];
% 'Output' : type de sortie (ex. 'Movie')
arg = [arg, {'mode', 'Display'}];
% 'Background' : couleur de fond (conversion de chaîne en vecteur numérique)
arg = [arg, {'background', [0 0 0]}];
% 'TextColor' : couleur du texte
arg = [arg, {'textColor', [1 1 1]}];
% 'FontSize' : taille de la police (conversion)
arg = [arg, {'fontSize', 12}];

% 'Scale' : facteur d'échelle pour le movie
% arg = [arg, {'ScalingFactor', str2num(dsM.MoviescaleEditField)}];
% select how to treat first class
arg = [arg, {'defaultClass', app.isthedefautcolorCheckBox.Value}];
% select painting mode
arg = [arg, {'paintChannel', app.DisplaySettings.Movie.paintChannel}];
arg = [arg, {'overlay', app.OverlayCheckBox.Value}];
% just one roi to be displayed
arg= [arg , {'Nrow',1}];
arg= [arg , {'Ncol',1}];
arg= [arg , {'Nbrick',3}];
arg= [arg , {'framerate',  str2num(app.DisplaySettings.Movie.MovieminutesperframeEditField)}];

arg= [arg , {'track',app.DisplaySettings.Movie.MoviedatatrackCheckBox}];
arg= [arg , {'trackWindow',str2num(app.DisplaySettings.Movie.MovietrackwindowEditField)}];
 arg= [arg , {'colormap',app.DisplaySettings.Movie.MoviecolormapEditField}];
 arg= [arg , {'dataColormap',app.DisplaySettings.Movie.MovieDatacolormapEditField}];

end
