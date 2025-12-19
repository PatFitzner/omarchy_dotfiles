# Declare a directory name within ~/.config 
# that you want to stow as the $i variable
# by running, for example: i="hypr".
# Run this script afterwards to migrate
# your ~/.config/hypr dotfiles to stow, 
# and commit them to git.

mkdir -p ./$i/.config
mv ~/.config/$i/ ./$i/.config/
stow $i
git add $i
git commit -m "+ $i"
echo "$i STOWED"
