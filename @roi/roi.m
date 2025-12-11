% buildReg1Snf1Dataset.m
%
% Charge un fichier Excel de type :
% Time | no 2DG (R1 R2 R3) | 0.05% (R1 R2 R3) | 0.2% | 0.5% | 1%
% Calcule la moyenne et l'écart-type des réplicats,
% construit un struct "data" et sauvegarde dans un .mat.
% Trace ensuite toutes les conditions sur le même plot avec
% bandes mean ± std (shaded error bars) et sauvegarde la figure.

%% Paramètres utilisateur
excelFile = 'Reg1_Snf1_NanoBit_2DG.xlsx';   % <-- à adapter
sheet     = 1;                              % ou 'Feuil1', etc.
matFile   = 'Reg1_Snf1_NanoBit_2DG.mat';    % fichier .mat de sortie
figFile   = 'Reg1_Snf1_NanoBit_2DG.fig';    % figure MATLAB
pdfFile   = 'Reg1_Snf1_NanoBit_2DG.pdf';    % figure PDF

%% Lecture du tableau Excel
opts = detectImportOptions(excelFile, 'Sheet', sheet, ...
                           'VariableNamingRule','preserve');
T = readtable(excelFile, opts);

% Vérification minimale
if width(T) < 16
    error('Le fichier doit contenir au moins 16 colonnes (Time + 5x3 réplicats).');
end

%% Extraction du temps
time = T{:,1};   % colonne 1 = Time

%% Extraction des blocs de réplicats (colonnes fixes)
% 2:4   = Reg1-Snf1 NanoBit, no 2DG
% 5:7   = Reg1-Snf1 NanoBit, 0.05%% 2DG
% 8:10  = Reg1-Snf1 NanoBit, 0.2%% 2DG
% 11:13 = Reg1-Snf1 NanoBit, 0.5%% 2DG
% 14:16 = Reg1-Snf1 NanoBit, 1%% 2DG

raw{1} = T{:,  2: 4};   % no 2DG
raw{2} = T{:,  5: 7};   % 0.05% 2DG
raw{3} = T{:,  8:10};   % 0.2%  2DG
raw{4} = T{:, 11:13};   % 0.5%  2DG
raw{5} = T{:, 14:16};   % 1%    2DG

condNames = { ...
    'Reg1-Snf1 NanoBit, no 2DG', ...
    'Reg1-Snf1 NanoBit, 0.05% 2DG', ...
    'Reg1-Snf1 NanoBit, 0.2% 2DG', ...
    'Reg1-Snf1 NanoBit, 0.5% 2DG', ...
    'Reg1-Snf1 NanoBit, 1% 2DG' ...
    };

condDG = [0, 0.05, 0.2, 0.5, 1];   % % 2DG (pour info)

%% Calcul moyenne + écart-type pour chaque condition
nCond = numel(raw);
conditions = struct([]);

for i = 1:nCond
    Y = raw{i};   % (nTime x 3), colonnes = R1 R2 R3

    % Moyenne et std sur les réplicats (par ligne)
    m  = mean(Y, 2, 'omitnan');
    sd = std(Y,  0, 2, 'omitnan');

    conditions(i).name      = condNames{i};
    conditions(i).DG        = condDG(i);  % concentration de 2DG (%)
    conditions(i).raw       = Y;          % données R1/R2/R3
    conditions(i).mean      = m;          % moyenne des réplicats
    conditions(i).std       = sd;         % écart-type des réplicats
    conditions(i).nRep      = size(Y,2);  % normalement 3
end

%% Struct final + sauvegarde .mat
data.time       = time;
data.conditions = conditions;
data.replicates = {'R1','R2','R3'};

save(matFile, 'data');
fprintf('Données sauvegardées dans %s\n', matFile);

%% Figure : toutes les conditions sur le même plot avec shaded error bars

figure('Name','Reg1-Snf1 NanoBit 2DG','Color','w'); hold on;

cmap = lines(nCond);    % palette de couleurs
hLines = gobjects(nCond,1);

for i = 1:nCond
    t  = time;
    m  = conditions(i).mean;
    sd = conditions(i).std;
    c  = cmap(i,:);

    % Bande mean ± std (shaded)
    xPatch = [t; flipud(t)];
    yPatch = [m - sd; flipud(m + sd)];
    hPatch = fill(xPatch, yPatch, c, ...
        'FaceAlpha', 0.15, 'EdgeColor', 'none'); %#ok<NASGU> (si pas utilisé)

    % Courbe de la moyenne
    hLines(i) = plot(t, m, '-', 'Color', c, 'LineWidth', 2);
end

xlabel('Time');
ylabel('Luminescence (a.u.)');
title('Reg1-Snf1 NanoBit ± 2DG');
legend(hLines, condNames, 'Location','best');
grid on;
box on;

% Sauvegarde de la figure
savefig(figFile);
fprintf('Figure sauvegardée (FIG) dans %s\n', figFile);

% Sauvegarde en PDF (pleine page)
set(gcf, 'PaperPositionMode','auto');
print(gcf, pdfFile, '-dpdf', '-bestfit');
fprintf('Figure sauvegardée (PDF) dans %s\n', pdfFile);
