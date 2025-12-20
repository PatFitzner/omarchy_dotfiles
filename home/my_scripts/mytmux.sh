#!/bin/bash

shopt -s expand_aliases

echo "HI"
SESSION1="Local"

# Only create tmux session if it doesn't already exist
# Start New Session with our name
tmux new-session -d -s $SESSION1
tmux send-keys C-m

# Start bash at home
tmux rename-window -t 0 'Home'
tmux send-keys -t 'Home' 'clear;neofetch' C-m
tmux splitw -h
# sleep 1
tmux send-keys -t 'Home' 'bpytop' C-m
tmux last-pane

# Create and setup pane for vim in my code dir
tmux new-window -t $SESSION1:1 -n 'Puig'
tmux send-keys -t 'Puig' 'puigdbt' C-m 'c' C-m
tmux splitw -h
tmux send-keys -t 'Puig' 'puigdbt' C-m 'c' C-m 'v' C-m

# Create and setup pane for vim in eva code dir
tmux new-window -t $SESSION1:2 -n 'EVA Code'
tmux send-keys -t 'EVA Code' 'evacodi' C-m 'c' C-m
tmux splitw -h
tmux send-keys -t 'EVA Code' 'evacodi' C-m 'c' C-m 'v' C-m

# setup eva aws server 1 connection
tmux new-window -t $SESSION1:3 -n 'EVAAWS'
tmux send-keys -t 'EVAAWS' "evaaws" C-m
# sleep 1
tmux send-keys -t 'EVAAWS' "tmux attach" C-m

# setup eva aws server 2 connection
tmux new-window -t $SESSION1:4 -n 'EVAAWS2'
tmux send-keys -t 'EVAAWS2' "evaaws2" C-m
# sleep 1
tmux send-keys -t 'EVAAWS2' "tmux attach" C-m

# # setup eva aws server 3 connection
# tmux new-window -t $SESSION1:3 -n 'EVAAWS3'
# tmux send-keys -t 'EVAAWS' "evaaws3" C-m
# tmux send-keys -t 'EVAAWS' "tmux attach" C-m

# Create and setup pane for vim in PUIG code
tmux new-window -t $SESSION1:1 -n 'Puig'
tmux send-keys -t 'Puig' 'puigdir' C-m 'c' C-m

# Attach Session, on the Main window
tmux attach-session -t $SESSION:0
