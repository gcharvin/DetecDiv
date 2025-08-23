function trainCellTRACKTRFun(classif, setparam)
% trainCellTRACKTRFun  Lance un entraînement Cell-TRACTR depuis MATLAB
% - Génère un YAML en préservant ordre + commentaires (remplacements texte)
% - target_size automatiquement = taille ROI (H,W)
% - train.py inchangé. On charge cfgs/train_<classif.strid>.yaml
%   mais à l'intérieur du YAML on met dataset: moma (requis par build_dataset).

if nargin == 2
    tip = {
        'Chemin complet vers le repo local Cell-TRACTR'
        'Nombre d''époques'
        'Batch size'
        'Learning rate'
        'Learning rate backbone'
        'Weight decay'
        'Nombre de workers pour le DataLoader'
        'Device (cuda ou cpu)'
    };

    classif.trainingParam = struct( ...
        'repo_path', 'C:\Users\charvin\SynologyDrive\mysoft\Cell-TRACTR', ...
        'epochs', 12, ...
        'batch_size', 2, ...
        'lr', 2e-4, ...
        'lr_backbone', 2e-5, ...
        'weight_decay', 1e-4, ...
        'num_workers', 4, ...
        'device', 'cuda', ...
        'tip', {tip} ...
    );
    disp('Training parameters initialised. Modify classif.trainingParam then run without setparam.');
    return;
end

TP = classif.trainingParam;
if isempty(TP)
    error('Training parameters not set. Run once with two arguments to initialise.');
end

%---------------- Vérification dataset COCO
coco_path = fullfile(classif.path, 'trainingdataset');
if ~exist(coco_path, 'dir')
    error('COCO dataset not found: %s\n→ Vérifie la conversion CTC→COCO.', coco_path);
end

%---------------- Vérification repo local
repo_path = TP.repo_path;
cfgs_path = fullfile(repo_path, 'cfgs');
if ~exist(cfgs_path, 'dir')
    error('cfgs folder not found in %s', repo_path);
end

yaml_original = fullfile(cfgs_path, 'train_moma.yaml');
if ~exist(yaml_original, 'file')
    error('Original YAML file not found: %s', yaml_original);
end

%---------------- Taille de ROI -> target_size (H,W)
if numel(classif.roi) < 1 || numel(classif.roi(1).value) < 4
    error('Invalid or missing ROI information in classif.');
end
roiW = classif.roi(1).value(3);
roiH = classif.roi(1).value(4);
target_size_str = sprintf('(%d,%d)', roiH, roiW);  % format attendu

%---------------- Lire le YAML original (texte brut)
yaml_txt = fileread(yaml_original);

%---------------- Normaliser chemins (slashes) et valeurs décimales fixes
outdir   = fixslashes(fullfile(classif.path, 'results', char(classif.strid)));
datadir  = fixslashes(fullfile(classif.path, 'trainingdataset'));
lr_str        = formatFixed(TP.lr);
lr_back_str   = formatFixed(TP.lr_backbone);
wd_str        = formatFixed(TP.weight_decay);

%---------------- Patcher les clés (ordre + commentaires conservés)
% IMPORTANT: on laisse dataset = 'moma' pour le dataset builder,
% mais on choisit le fichier YAML via train_<classif.strid>.yaml
yaml_txt = setYamlScalar(yaml_txt, 'dataset',        'moma');                      % pour build_dataset
yaml_txt = setYamlScalar(yaml_txt, 'target_size',    target_size_str);
yaml_txt = setYamlScalar(yaml_txt, 'output_dir',     outdir);
yaml_txt = setYamlScalar(yaml_txt, 'data_dir',       datadir);

% Hyperparamètres éventuels
yaml_txt = setYamlScalar(yaml_txt, 'epochs',         TP.epochs);
yaml_txt = setYamlScalar(yaml_txt, 'batch_size',     TP.batch_size);
yaml_txt = setYamlScalar(yaml_txt, 'lr',             lr_str);          % décimal fixe
yaml_txt = setYamlScalar(yaml_txt, 'lr_backbone',    lr_back_str);     % décimal fixe
yaml_txt = setYamlScalar(yaml_txt, 'weight_decay',   wd_str);          % décimal fixe
yaml_txt = setYamlScalar(yaml_txt, 'num_workers',    TP.num_workers);

% Supprimer CoMOT si présent
%yaml_txt = regexprep(yaml_txt, '^\s*CoMOT\s*:\s*.*\n', '', 'lineanchors');

% Nettoyer les booléens (forcer en lowercase YAML)
yaml_txt = regexprep(yaml_txt, '\<True\>', 'true');
yaml_txt = regexprep(yaml_txt, '\<False\>', 'false');


dev = TP.device; if iscell(dev), dev = dev{end}; end
yaml_txt = setYamlScalar(yaml_txt, 'device',         char(dev));

%---------------- Enregistrer le YAML généré : train_<strid>.yaml
yaml_name = ['train_' char(classif.strid) '.yaml'];
yaml_path = fullfile(cfgs_path, yaml_name);
fid = fopen(yaml_path, 'w');
if fid == -1, error('Unable to write YAML file: %s', yaml_path); end
fwrite(fid, yaml_txt, 'char');
if ~endsWith(yaml_txt, sprintf('\n')), fwrite(fid, sprintf('\n')); end
fclose(fid);
disp(['[OK] YAML saved to: ' yaml_path]);

%---------------- Lancement Python (train.py) inchangé
repo_path_esc = strrep(repo_path, '\', '\\');
py_script = sprintf( ...
"import os, sys, runpy\n" + ...
"os.chdir(r'%s')\n" + ...
"os.environ['PYTHONPATH'] = r'%s'\n" + ...
"sys.path.insert(0, os.path.join(r'%s', 'src'))\n" + ...
"os.environ['CONDA_PREFIX'] = os.path.dirname(sys.executable)\n" + ...
"print('CWD:', os.getcwd())\n" + ...
"print('PYTHONPATH:', os.environ.get('PYTHONPATH'))\n" + ...
"print('sys.path:', sys.path)\n" + ...
"sys.argv = ['src/train.py', 'with', 'cfgs/train_%s.yaml']\n" + ...
"runpy.run_path('src/train.py', run_name='__main__')\n", ...
repo_path_esc, repo_path_esc, repo_path_esc, classif.strid);


launcher = fullfile(classif.path, 'train_celltractr_script.py');
fid = fopen(launcher, 'w');
if fid == -1, error('Unable to create Python script: %s', launcher); end
fprintf(fid, '%s', py_script);
fclose(fid);
disp(['[OK] Python launcher saved to: ' launcher]);

python_env = pyenv();
if strcmp(python_env.Status, 'NotLoaded')
    error('Python environment not loaded. Activate an environment before running this script.');
else
    disp(['Active Python env: ' python_env.Executable]);
end

try
    pyrunfile(launcher);
    disp('[OK] Cell-TRACTR training finished successfully.');
catch ME
    disp('[ERROR] during Python script execution.');
    disp(ME.message);
end
end

% ===================== Helpers =====================

function s = fixslashes(p)
    % Windows paths -> forward slashes to éviter \t, \b, \a dans YAML
    s = strrep(p, '\', '/');
end

function txt = setYamlScalar(txt, key, val)
    % Remplace la valeur d'une clé YAML en préservant indentation / commentaires.
    if islogical(val)
        valStr = lower(string(val));
    elseif isnumeric(val)
        valStr = num2str(val);  % on passe déjà des strings décimales pour lr, etc.
    else
        valStr = string(val);
    end
    valStr = char(valStr);

    pattern = ['^(\s*)' , regexptranslate('escape', key), '\s*:\s*([^\n#]*?)(\s*#.*)?$'];
    newtxt  = regexprep(txt, pattern, ['$1' key ': ' valStr '$3'], 'once', 'lineanchors');

    if strcmp(newtxt, txt)
        % clé non trouvée → on l'ajoute en fin (optionnel)
        warning('Key "%s" not found in YAML. Appending at the end.', key);
        if ~endsWith(txt, sprintf('\n')), txt = [txt sprintf('\n')]; end
        newtxt = sprintf('%s%s: %s\n', txt, key, valStr);
    end
    txt = newtxt;
end

function s = formatFixed(x)
    % Retourne une chaîne décimale sans notation scientifique (ex: 0.00002)
    if ~isnumeric(x), s = char(string(x)); return; end
    if x == 0
        s = '0';
        return;
    end
    mag = floor(log10(abs(x)));
    if mag <= -3 || mag >= 6
        % petit ou très grand -> forcer décimal avec suffisamment de précision
        s = sprintf('%.10f', x);
    else
        % plage "normale"
        s = sprintf('%.10f', x);
    end
    % nettoyer: enlever zéros/point superflus
    s = regexprep(s, '0+$', '');
    s = regexprep(s, '\.$', '');
    if startsWith(s, '-0.') && all(s(3:end) ~= '0')
        % garder le signe -0.x si nécessaire
        return;
    end
    if startsWith(s, '0.') || startsWith(s, '-0.')
        % OK
    elseif startsWith(s, '-0') && ~contains(s, '.')
        % -0 -> 0
        s = '0';
    end
end
