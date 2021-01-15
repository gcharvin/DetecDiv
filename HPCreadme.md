ssh hpc.igbmc.fr

In the terminal:
————————------

% start new job :
sinteractive -p gpu --gres=gpu:8 --cpus-per-gpu=1 --mem=120GB

% list jobs :
squeue

% cancel job to allow other users to use the node :
scancel jobnumber

% (optional) resume job on node 1:
ssh phantom-node1s
screen -r

% load Matlab module
 module load matlab/R2019b

% load Matlab
matlab

In Matlab :
—————------
% update shallow distribution (assuming the Matlab path is correctly set):
cd /shared/space2/charvin/matlab/shallow
!git pull

% set the parallel pooler with 8 workers
parpool('local',8)
