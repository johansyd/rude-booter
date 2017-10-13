# The Rude Booter
The rude booter may curse and swear at you, but he will also bootstrap your development environment.

## Website

Go to: [The Rude Booter](https://johansyd.github.io/rude-booter/)

## Setup

You should setup your own vagrant bootstrap project on github. see: [example](https://github.com/johansyd/vagrant-bootstrap)
The Rude Booter will use this project as the bootstrap base for setting upp all of the projects defined in your vagrant file.
You can use [example](https://github.com/johansyd/vagrant-bootstrap) as a start for defining your own vagrant bootstraper.

### Instructions

the VagrantFile should be in the folder: `./vagrant`
If you want to install vagrant plugins as part of the installation. add a file at the base of your project with the name: `vagrant_plugins`
Each plugin should be on a separate line.
Th Rude Booter will clone out all your projects in a folder that you specify. You can use this fact to setup your projects as vhosts that can be used by vagrant to provision them as shared folders.
The Rude Booter can also run a installation script for each of your projects. Just specify the path to the installation file during the installation process. By default, the Rude Booter will use `scripts/install.sh` from the base of any github project that you have told it to clone.

## Installation

### Dependencies for Windows

Recommended:

- Install [babun](http://babun.github.io/)

Required:

NB: Comes preinstalled with most systems including [babun](http://babun.github.io/)

- Install [Python](https://www.python.org/downloads/release/python-2713/)

## Usage Mac/Ubuntu/(Windows with Cygwin)

In these examples I install my bootstrap project in ~/

If you are using cygwin. Please install babun, open File Explorer, right click and choose: "open babun here"

    cd ~/
    bash <(\curl -s "https://raw.githubusercontent.com/johansyd/rude-booter/master/scripts/install.sh")
    ## 1. I will tell the Rude Booter that my organization is johansyd
    ## 2. I will then tell him that my bootstrap project's name is: [vagrant-bootstrap](https://github.com/johansyd/vagrant-bootstrap)
    ## 3. I will tell him that my vhosts folder should be: vhosts and not ../vhosts
    ## 4. I can the choose to clone out a repository and choose vhost.vagrant.domain.com to be my shared folder on the host side.
