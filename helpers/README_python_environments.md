# Environnements Python DetecDiv

La procédure canonique est portée par deux fichiers :

- `detecdiv_python_recipe.m` contient les versions et les paquets attendus ;
- `select_and_load_conda_env.m` crée, complète et vérifie l'environnement.

Les modules CellposeSAM et Trackastra ne doivent donc pas maintenir une
seconde procédure d'installation. Trackastra est installé par défaut avec
ses dépendances d'entraînement (`trackastra[train]`).

## Windows

```matlab
info = select_and_load_conda_env('mode', 'default');
```

Le backend Windows utilise l'environnement Conda `detecdiv_python`, puis le
charge dans MATLAB avec `pyenv` en mode `OutOfProcess`.

## WSL

```matlab
info = select_and_load_conda_env( ...
    'backend', 'wsl', ...
    'mode', 'default');
```

Le backend WSL utilise par défaut la distribution et le chemin déclarés dans
la recette. Ils peuvent être remplacés sans introduire de chemin dans les
paramètres statiques d'un classifier :

```matlab
info = select_and_load_conda_env( ...
    'backend', 'wsl', ...
    'mode', 'default', ...
    'wslDistro', 'Ubuntu-24.04', ...
    'wslEnvPath', '/home/user/venvs/detecdiv_python');
```

Les variables `DETECDIV_WSL_DISTRO` et `DETECDIV_WSL_ENV_PATH` constituent
aussi des surcharges locales possibles.

Le mode `custom` vérifie un environnement existant sans installer les paquets
DetecDiv :

```matlab
info = select_and_load_conda_env( ...
    'backend', 'wsl', ...
    'mode', 'custom', ...
    'wslEnvPath', '/home/user/venvs/sam3');
```

Cette fonction prépare et inspecte l'environnement WSL. Le routage de
l'exécution d'un classifier vers WSL reste le contrat propre à son runner ;
la sélection de l'environnement ne transforme pas automatiquement un appel
Python Windows en appel WSL.
