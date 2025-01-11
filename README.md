# legobattlesrompacker
A program that automates packing of mods for lego battles
install deps
```
sudo apt install zip unzip xxd fuse-overlayfs

```


How to install
```
git clone https://github.com/lnee94/legobattlesrompacker.git
cd legobattlesrompacker
chmod +x *
wget https://github.com/haroohie-club/NitroPacker/releases/download/3.0.2/NitroPacker-Linux-3.0.2.tar.gz
tar -xf NitroPacker-Linux-3.0.2.tar.gz
sudo mv NitroPacker /usr/local/bin/nitro
rm NitroPacker-Linux-3.0.2.tar.gz
sudo ln -s "$(realpath com)" /usr/local/bin/com
sudo chmod +x /usr/local/bin/com
cd ..
```

How to set up
```
mkdir rombuild
cd rombuild
com --setup /PATH/TO/ROM/FILE.nds
```
How to use symplly put lbz files in the apropate mods filder and in the base directory run com








Creddits 
https://github.com/haroohie-club/NitroPacker for the rom packing
https://github.com/Anvil/bash-argsparse for argument parsing
https://github.com/froggestspirit/SDATTool for unpacking sdat files
