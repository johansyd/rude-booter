# The Rude Booter
The rude booter may curse and swear at you, but he will also bootstrap your development environment.

## Website

Go to: [The Rude Booter](https://johansyd.github.io/rude-booter/)

## Setup

You should setup your own vagrant bootstrap project on github. see: [example](https://github.com/johansyd/vagrant-bootstrap)
The Rude Booter will use this project as the bootstrap base for setting upp all of the projects defined in your vagrant file.
You can use [example](https://github.com/johansyd/vagrant-bootstrap) as a start for defining your own vagrant bootstraper.

### Instructions

Please read [How to setup your first bootstrap project](https://github.com/johansyd/rude-booter/wiki/How-to-setup-your-first-bootstrap-project)

## Installation

#### Windows

#### Recommended:

- Install [babun](http://babun.github.io/)

#### Required:

NB: Comes preinstalled with most systems including [babun](http://babun.github.io/)

- [Python 2.7.13](https://www.python.org/downloads/release/python-2713/)

## Usage Mac/Ubuntu/(Windows with Cygwin)

In these examples I install my bootstrap project in ~/

If you are using cygwin. Please install babun, open File Explorer, right click and choose: "open babun here"

    cd ~/
    bash <(\curl -s "https://raw.githubusercontent.com/johansyd/rude-booter/master/scripts/install.sh")
    
1. I will tell the Rude Booter that my organization is johansyd
2. I will then tell him that my bootstrap project's name is: [vagrant-bootstrap](https://github.com/johansyd/vagrant-bootstrap)
3. The rude Booter will then look at my .rude-booter.json config and clone out my projects and install any vagrant plugins.
