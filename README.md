# rude-booter
The rude booter may curse and swear at you, but he will also bootstrap your development environment.

## Setup

You should setup a vagrant bootstrap project on github.

the VagrantFile should be in the folder: `./vagrant`
If you want to install vagrant plugins as part of the installation. add a file at the base of your project with the name: `vagrant_plugins`
Each plugin should be on a separate line.
Th Rude Booter will clone out all your projects in a folder that you specify. You can use this fact to setup your projects as vhosts that can be used by vagrant to provision them as shared folders.
The Rude Booter can also run a installation script for each of your projects. Just specify the path to the installation file during the isntallation process. By default, the Rude Booter will use `scripts/install.sh` from the base of any github project you tell it to clone.

## Installation

### Dependencies for Windows

Recommended:

- Install [babun](http://babun.github.io/)
- Install [vagrant](https://www.vagrantup.com/downloads.html)
- Install [virtualbox](https://www.virtualbox.org/)

Optional:

NB: needed if you want to be able to build projects from Windows. Certain project installations might fail depending on whether the build step is included in the installation process.

- Install [.NET Framework 2.0 Software Development Kit](https://www.microsoft.com/en-us/download/details.aspx?id=15354)
- Install [Visual Studio Express](https://www.visualstudio.com/vs/visual-studio-express/)
- Install [Python](https://www.python.org/downloads/release/python-2713/)

## Usage Mac/Ubuntu/(Windows with Cygwin)

In these examples I install my bootstrap project in ~/

If you are using cygwin. Please install babun, open File Explorer, right click and choose: "open babun here"

    cd ~/
    bash <(\curl -s "https://raw.githubusercontent.com/johansyd/rude-booter/master/scripts/install.sh")
    
