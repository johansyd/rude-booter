#!/usr/bin/env bash
#
# Simple bootstrapping program for the "phonect" project.
# Should work on Darwin and Debian
set -o errtrace
set -o errexit
set -o pipefail

# Text color variables
declare -r txtund=$(tput sgr 0 1)          # Underline
declare -r txtbld=$(tput bold)             # Bold
declare -r bldred=${txtbld}$(tput setaf 1) #  red
declare -r bldyellow=${txtbld}$(tput setaf 3) #  yellow
declare -r bldgreen=$(tput setaf 2) #  green
declare -r bldpurp=${txtbld}$(tput setaf 5) #  purple
declare -r bldblu=${txtbld}$(tput setaf 4) #  blue
declare -r bldwht=${txtbld}$(tput setaf 7) #  white
declare -r txtrst=$(tput sgr0)             # Reset
declare -r isNumber='^[0-9]+$';
declare vagrant_repo='';
declare vagrant_repo_ssh='';
declare -r git_ssh_url='git@github.com';
declare -r boot_project_suffix='-vagrant';
declare -r default_path_to_project_scripts='scripts/install.sh';
declare -r default_boot_project_vhosts='../vhosts';
declare boot_project_vhosts='';
declare github_org='';
declare git_bootstrap_project='';
declare all_projects_installed='no';
declare create_all_repos_from_file_has_run=false;
declare installdir="";
# make sure we don't leave the terminal with some strange color
trap "printf '%b${txtrst}'" EXIT;

function say () {
    printf "\n${bldwht}%b${txtrst}\n" "$*";
}

function brag () {
    printf "\n${bldpurp}%b${txtrst}\n" "$*";
}

function warn () {
    printf "\n${bldyellow}WARN: %b${txtrst}\n" "$*";
}

function error () {
    printf "\n${bldred}ERROR: %b${txtrst}\n" "$*";
}

function fail () {
    printf "\n${bldred}FATAL ERROR: %b${txtrst}\n" "$*";
    exit 1;
}

function info () {
    printf "\n${bldgreen}%b${txtrst}\n" "$*";
}

function prompt_yes_no () {
    local choice;
    builtin read -p "${bldblu}$1 (y/n): ${txtrst}" -r choice;
    case $choice in
        y|Y) echo "yes";;
        n|N) echo "no";;
        *) echo "invalid";;
    esac
}

function prompt_string () {
    local answer;
    builtin read -ep "${bldblu}$1:${txtrst}

" -r answer;
    if [ ! -z "$answer" ]; then
        echo $answer;
        return 0;
    else
        return 1;
    fi
}

function wait_for_keypress () {
    local answer;
    builtin read -n 1 -p "${bldblu}Press any key to continue${txtrst}" -r answer;
}


function open_url () {
    local -r url=$1;
    
    case "$(uname)" in
        Darwin)
            open $1;
            ;;
        Linux)
            BROWSER=${BROWSER:-};
            if [ ! -z "$BROWSER" ]; then
                $BROWSER "$url";
            elif which xdg-open > /dev/null; then
                xdg-open "$url";
            elif which gnome-open > /dev/null; then
                gnome-open "$url";
            else
                warn "What kind of webbrowser are you using on your system anayway? curl???
Have you been living under a stone? Chrome is the shit!! 
Please copy&past this url: $url.
and open it in your marginated Hyper Text Transport Protocol Reader";
            fi
            ;;
        *)
            if which cygstart > /dev/null; then
                cygstart "$url";
                return 0;
            fi
            warn "You are using Windows!! Yuck!! Shame on yourself.
copy&past this url: $url. and open it in your marginated 
Hyper Text Transport Protocol Reader";
            ;;
    esac
    return 0;
}

function abort_not_installed () {
    local -r progname=$1;
    local -r prog_url=$2;

    say "You do not have $progname, and you call yourself a developer? Incompetent fool!";
    local answer=$(prompt_yes_no \
        "I will give you on more chance to go to the $progname website "\
        "to download and install it ASAP. Will You do it?");
    [[ $answer == "yes" ]] && open_url $prog_url;
    answer=$(prompt_yes_no \
        "Have you managed to install this $programe crap yet?");
    [[ $answer == "yes" ]] && say "Good boy. Now go and roll over." && return 0;
    warn "\nYou are such an idiot! I guess you have to do it manually. "\
        "Try to run this script again before bothering the guy that wrote me.";
    return 2;
}

function abort_too_old () {
    local -r progname=$1;
    local -r prog_url=$2;
    local -r minver=$3;

    say "$progname is too old, and so are you (you need at least $minver)!";
    local answer=$(prompt_yes_no \
        "Do you want to visit the $progname website to upgrade your ass?");
    [[ $answer == "yes" ]] && open_url $prog_url;
    answer=$(prompt_yes_no \
        "Have you managed to install this $programe crap yet?");
    [[ $answer == "yes" ]] && say "Good! I guess you are cool again" && return 0;
    warn "\nTry running this script again after upgrading $progname, you old unix dog!";
    return 2;
}

# http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format
function vercomp () {
    if [ $1 == $2 ];then
        echo 0;
        return 0;
    fi
    local IFS=.;
    local i ver1=($1) ver2=($2);
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0;
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [ -z ${ver2[i]} ];then
            # fill empty fields in ver2 with zeros
            ver2[i]=0;
        fi
        if [ ${ver1[i]} -gt ${ver2[i]} ];then
            echo 1;
            return 0;
        fi
        if [ ${ver1[i]} -lt ${ver2[i]} ];then
            echo 2;
            return 0;
        fi
    done
    echo 0;
    return 0;
}

function found () {
    hash $1 2>&-;
}

# installs all dependencies given as arguments
function deps () {
    local dep;
    local last=$(expr $#)
    local last_dep=${@:$last};

    for dep in $@; do
        if [ "$(type -t is_${dep}_installed)" == 'function' ]; then
            if ! is_${dep}_installed; then
                if [ $(type -t install_$dep) == 'function' ]; then
                    info "Installing $dep...";
                    install_$dep && [ "${last_dep}" = "${dep}" ] && return 0 || continue;
                    error "Could not install $dep." \
                        "Please don't send med to /dev/null to die!"\
                        " I promise to be good next time.";
                    return 1;
                fi
                error "There are no function called install_${dep}.";
                error "$dep is not installed and no code to install it was found." \
                    "Please don't send med to /dev/null to die! I promise to be good next time.";
                return 1;
            fi
            [ "${last_dep}" = "${dep}" ] && return 0 || continue;
        fi
        error "There are no function called is_${dep}_installed.";
        return 1;
    done
    return 0;
}

function is_nvm_installed () {
    found nvm || return 1;
    return 0;
}

function install_nvm () {
    local -r win_nvm_url='https://github.com/coreybutler/nvm-windows/releases';
    pushd ~/ >/dev/null;
    local home=$(pwd);
    popd;
    say "Setting up nvm";
    case "$(uname)" in
        Darwin)
            if [ ! -d "$home/.nvm" ]; then
              (nvm --version >/dev/null && info "nvm already installed") || (say "Fetching and compiling nvm" && curl https://raw.githubusercontent.com/creationix/nvm/v0.11.1/install.sh | bash && info "nvm was installed") || error "nvm could not be installed.";
            fi
            export NVM_DIR="$home/.nvm";
            [ -s "$NVM_DIR/nvm.sh" ] && source $NVM_DIR/nvm.sh;
            ;;
        Linux)
            if [ ! -d "$home/.nvm" ]; then
              (nvm --version >/dev/null && info "nvm already installed") || (say "Fetching and compiling nvm" && curl https://raw.githubusercontent.com/creationix/nvm/v0.11.1/install.sh | bash && info "nvm was installed") || error "nvm could not be installed.";
            fi
            export NVM_DIR="$home/.nvm";
            [ -s "$NVM_DIR/nvm.sh" ] && source $NVM_DIR/nvm.sh;
            ;;
        *)
            say "We are assumming that you are using cygwin. There is a version of nvm called nvm-windows, but you have to install it manually.";
            local answer=$(prompt_yes_no \
                "Do you want to go to the website where the recipy is?");
            ([[ $answer == "yes" ]] && open_url $win_nvm_url) || error "we are unable to install node for you.";
            found nvm || abort_not_installed "nvm" $win_nvm_url;
    esac
    answer='no';
    is_nvm_installed && return 0;
    answer=$(prompt_yes_no "Do you want to try installing nvm again?");
    [[ $answer == "yes" ]] && install_nvm;
    return 0;    
}

### virtualbox

function is_virtualbox_installed () {
    found VBoxManage || return 1;
    return 0;
}

function install_virtualbox () {
    local -r virtualbox_url='https://www.virtualbox.org/';
    case "$(uname)" in
        Darwin)
            abort_not_installed "VirtualBox" $virtualbox_url || return 1;
            return 0;
            ;;
        Linux)
            if found apt-get; then
                say "Trying to install virtualbox - this might require god given sudo powers.";
                if (( UID )); then
                    sudo apt-get install virtualbox || return 1;
                    sudo apt-get install virtualbox-dkms || return 1;
                else
                    apt-get install virtualbox || return 1;
                    apt-get install virtualbox-dkms || return 1;
                fi
            fi
            return 0;
            ;;
        *)
            is_virtualbox_installed && return 0;
            error "Could not install virtualbox. You incompetent fool. \n"\
            "I guess you have to do it manually. Try running this script again before \n"\
            "bothering the guy that wrote me.";

            info "You will need to install virtualbox, but are working from a system where this can not automaticly be installed.";
            local answer=$(prompt_yes_no \
                "Do you want to go to the website where the recipy is?");
                [[ $answer == "yes" ]] && 
                open_url "https://www.virtualbox.org/wiki/Downloads" || 
                warn "I might not be able to setup $git_bootstrap_project without you setting up virtualbox.";
            answer=$(prompt_yes_no \
                "Have you installed virtualbox yet?");
                [[ $answer == "yes" ]] && 
                info "Continuing the installation." ||
                warn "I might not be able to setup $git_bootstrap_project without you setting up virtulbox.";
            found ruby || warn "could not install virtualbox. Please see: https://www.virtualbox.org/wiki/Downloads";
    esac
    is_virtualbox_installed && return 0;
    answer=$(prompt_yes_no "Do you want to try installing virtualbox again?");
    [[ $answer == "yes" ]] && install_virtualbox || warn "You will probably have problems running vagrant.";
    return 0;
}

### ruby
function install_ruby () {
    case "$(uname)" in
        Darwin)
            ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
            brew install rbenv ruby-build
            echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bash_profile
            source ~/.bash_profile
            rbenv install 2.3.1
            rbenv global 2.3.1
            ruby -v
            ;;
        Linux)
            if found apt-get; then
                say "Trying to install ruby - this might require god given sudo powers.";
                if (( UID )); then
                    sudo apt-get install ruby;
                else
                    apt-get install ruby;
                fi
            fi
            ;;
        CYGWIN_NT-10.0-WOW)
            pact install patch gnupg bison libtool mingw64-i686-gcc-core mingw64-x86_64-gcc-core libcrypt-devel libyaml-devel libyaml0_2 libffi-devel sqlite3 patch gnupg
            curl -#L https://get.rvm.io | bash -s stable --autolibs=3 --ruby=1.9.3
            rvm use 1.9.3
            found ruby || warn "\nCould not install ruby in babun. You incompetent fool. "\
            "I guess you have to do it manually. Try installing ruby before "\
            "bothering the guy that wrote me.";
            ;;
        *)
            
            found ruby && return 0;
            warn "\nCould not install ruby. You incompetent fool. "\
            "I guess you have to do it manually. Try installing ruby before "\
            "bothering the guy that wrote me.";
            info "You will need to install ruby, but are working from a system where this can not automaticly be installed.";
            info "I would recommend that you install rvm which make you able to run multiple versions of ruby on your system.";
            local answer=$(prompt_yes_no \
                "Do you want to go to the website where the recipy is?");
                [[ $answer == "yes" ]] && 
                open_url "https://vaporsoft.net/setting-up-rvm-with-cygwin/" || 
                warn "I might not be able to setup $git_bootstrap_project without you setting up ruby.";
            answer=$(prompt_yes_no \
                "Have you installed ruby yet?");
                [[ $answer == "yes" ]] && 
                info "Continuing the installation." ||
                warn "I might not be able to setup $git_bootstrap_project without you setting up ruby.";
            found ruby || warn "could not install ruby. Please see: https://vaporsoft.net/setting-up-rvm-with-cygwin/";
    ;;
    esac
    is_ruby_installed && return 0;
    answer=$(prompt_yes_no "Do you want to try installing ruby again?");
    [[ $answer == "yes" ]] && install_ruby || warn "You will probably have problems running vagrant.";
    return 0;
}

function is_ruby_installed () {
    found ruby;
}

### ssh

function install_ssh () {
    case "$(uname)" in
        Darwin)
            deps 'ruby';
            brew install openssh && return 0;
            ;;
        Linux)
            if found apt-get; then
                say "Trying to install ssh - this might require god given sudo powers";
                if (( UID )); then
                    sudo apt-get install openssh-client && return 0;
                else
                    apt-get install openssh-client && return 0;
                fi
            fi
            error "You do not have apt-get on your system." && return 1;
            ;;
        *)
            is_ssh_installed && return 0;
            info "You will need to install ssh, but are working from a system where this can not automaticly be installed.";
            info "I would recommend that you install babun which is a version of cygwin where ssh is already setup for you.";
            local answer=$(prompt_yes_no \
                "Do you want to go to the website where the recipy is?");
                [[ $answer == "yes" ]] && 
                open_url "http://babun.github.io/" || 
                warn "I might not be able to setup $git_bootstrap_project without you setting up ssh.";
            answer=$(prompt_yes_no \
                "Have you installed babun or ssh?");
                [[ $answer == "yes" ]] && 
                info "Continuing the installation." ||
                warn "I might not be able to setup $git_bootstrap_project without you setting up ssh.";
            found ssh-add || warn "could not install ssh. Please see: http://babun.github.io/";
    esac
    is_ssh_installed && return 0;
    answer=$(prompt_yes_no "Do you want to try installing ssh again?");
    [[ $answer == "yes" ]] && install_ssh || warn "You will have to use a git token. You will get more information when we get to that step.";
    return 0;
}

function is_ssh_installed () {
    found ssh;
}

function ssh_list_keys () {
    eval `ssh-agent -s`;
    if [[ "$(ssh-add -L)" =~ 'no identities' ]]; then
        if [[ -d ~/.ssh && -e ~/.ssh/id_rsa.pub ]]; then
            cat ~/.ssh/id_rsa.pub;
        else
            warn "no ssh keys found. Who are you anyway?";
        fi
    else
        ssh-add -L;
    fi
}

function generate_ssh_key () {
    email=$(prompt_string "Please enter your email address (will be used in your ssh key "\
        "and not to spam your ass motherfucker!");

    if ssh-keygen -t rsa -C "$email"; then
        say "Now I know who you are. You are good dam ugly. I guess you aren't a motherfucker after all.".
        say "The ssh key should be listed below:"
        ssh_list_keys;
        if [[ -e ~/.ssh/id_rsa.pub && "$(uname)" == "Darwin" ]]; then
            pbcopy < ~/.ssh/id_rsa.pub;
            say "The public key generated has been copied for your sorry ass to the "\
                "clipboard (ready to be pasted into your looser github ssh key page)";
        fi
        return 0;
    else
        error "Could not generate a new ssh key for you. You incompetent fool! "\
            "I guess you have to do it manually. Try running this script again before "\
            "bothering the guy that wrote me.";
    fi
}

function has_ssh_keys () {
    [[ ( -d ~/.ssh && -e ~/.ssh/id_rsa.pub ) || ! ( "$(ssh-add -L)" =~ 'no identities' ) ]];
}

### git
function is_git_installed () {
    found git;
}

### git
function is_gitlfs_installed () {
    found git-lfs;
}

function install_gitlfs() {
  deps 'git';

    case "$(uname)" in
        Darwin)
            deps 'ruby';
            brew install git-lfs || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
            git lfs install || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
            ;;
        Linux)
            if found apt-get; then
                say "Trying to install the amazingly cool git - this might require god given sudo powers.";
                if (( UID )); then
                    (sudo apt-get -y install software-properties-common || sudo apt-get -y install python-software-properties) || warn "could not install the relevant git-lfs dependnecies. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                    sudo add-apt-repository -y ppa:git-core/ppa || warn "could not add the  git-lfs repository. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                    sudo apt-get -y update || warn "Could not update your package manager.";
                    (curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash) || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                    sudo apt-get -y install git-lfs || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                else
                    (apt-get -y install software-properties-common || apt-get -y install python-software-properties) || warn "could not install the relevant git-lfs dependnecies. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                    add-apt-repository -y ppa:git-core/ppa || warn "could not add the  git-lfs repository. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                    apt-get -y update || warn "Could not update your package manager.";
                    (curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash) || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
                    apt-get -y install git-lfs || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";

                fi
                git lfs install || warn "could not install git-lfs. Please see: https://github.com/git-lfs/git-lfs/wiki/Installation";
            fi
            ;;
        *)
            info "You will need to install git-lfs, but are working from a system where this can not automaticly be installed.";
            local answer=$(prompt_yes_no \
                "Do you want to go to the website where the recipy is?");
                [[ $answer == "yes" ]] && 
                open_url "https://git-lfs.github.com/" || 
                warn "I will not be able to setup $git_bootstrap_project without you setting up git-lfs.";
            answer=$(prompt_yes_no \
                "Have you installed git-lfs?");
                [[ $answer == "yes" ]] && 
                warn "The Babun/Cygwin terminal needs to be closed and reopned before you can continue with the installation. Please restart the script after you have done so." && exit 0;
                
    esac
    is_gitlfs_installed && return 0;
    answer=$(prompt_yes_no "Do you want to try installing gitlfs again?");
    [[ $answer == "yes" ]] && install_gitlfs || warn "You might get issues if the project you bootstrap are using gitlfs.";
    return 0;
}

function install_git () {
    case "$(uname)" in
        Darwin)
            deps 'ruby';
            brew install git || warn "could not install git with brew. MAke sure git gets properly installed.";
            ;;
        Linux)
            if found apt-get; then
                say "Trying to install the amazingly cool git - this might require god given sudo powers.";
                if (( UID )); then
                    sudo apt-get -y update || warn "Could not update your package manager.";
                    sudo apt-get -y install git || warn "Could not install git";
                else
                    apt-get -y update || warn "Could not update your package manager.";
                    apt-get -y install git || warn "Could not install git";

                fi
            fi
            ;;
        *)
            info "You will need to install git, but are working from a system where this can not automaticly be installed.";
            local answer=$(prompt_yes_no \
                "Do you want to go to the website where the recipy is?");
                [[ $answer == "yes" ]] && 
                open_url "https://git-scm.com/download/win" || 
                warn "I will not be able to setup $git_bootstrap_project without you setting up git.";

            answer=$(prompt_yes_no \
                "Have you installed git?");
                [[ $answer == "yes" ]] && 
                info "Continuing the installation." ||
                warn "I will not be able to setup $git_bootstrap_project without you setting up git.";
    esac
    is_git_installed && return 0;
    answer=$(prompt_yes_no "Do you want to try installing git again?");
    [[ $answer == "yes" ]] && install_git || warn "You might get issues if the project you bootstrap are stored in git.";
    return 0;
}

### Access to github
function is_gitaccess_installed () {
    deps 'ssh' || 
        (error "Could not install gitaccess dependencies: ssh. Please don't send me to /dev/null to die!!!" && return 1);
    local answer=$(ssh -T git@github.com 3>&1 1>&2- 2>&3-);
    [[ "$answer" =~ "successfully authenticated" ]];
}

# FIXME: To be able to correctly generate a ssh key.
# I would have to ensure that the sshd is running.
# This is more work then I want to do. So I would just
# tell the user to do it manually.
function install_gitaccess () {
    deps 'git' 'ssh' || 
        (error "could not install gitaccess dependencies: git and ssh. Please don't send me to /dev/null to die!!!" && return 1 );
    warn "You do not have a proper ssh key to access git hub. "\
        "You will have to create one. We can take you to a website "\
        "where you can follow a recipy that will give you access.";
    local answer=$(prompt_yes_no \
        "Do you want to go to the website where the recipy is?");
        [[ $answer == "yes" ]] && 
        open_url "https://help.github.com/articles/generating-ssh-keys/" || 
        warn "I will not be able to setup phonect without you setting up a ssh key.";
    local success=false;
    display_github_sshkey_message && success=true || success=false;
    while [ $success == false ]
    do
        display_github_sshkey_message && success=true || success=false;
        [ $success == false ] && warn "You did not setup proper github access, mooron!!" &&
            repeat_or_fail_prompt && continue || return 1;
        ! is_gitaccess_installed && warn "Oh, but the key(s) you have doesn't appear to work with github? "\
            "What could I expect from a moroon like you. Your existing public keys:" &&
            ssh_list_keys && say "" &&
            repeat_or_fail_prompt && success=false && continue || return 1;
    done
    say "It seems that you can access github with your ssh key.";
    return 0;
}

function display_github_sshkey_message () {
    say "You need to configure github with (one of) your shitty ass ssh public keys.\n"\
        "Log into your looser github account and add the shitty ssh key.\n"\
        "You will be sent to their stupid site where this can be done.\n"\
        "Do I need to do everything around here? Press enter please!";
    wait_for_keypress;
    open_url 'https://github.com/settings/ssh';
    repeat_or_fail_git_prompt && return 0 || return 1;
}

function repeat_or_fail_git_prompt() {
    local answer=$(prompt_yes_no \
        "Have you done the crap I told you yet?
You know, git ssh key?, github page? copy&past? chop, chop.
what are you waiting for!");
    [[ $answer == "yes" ]] || error "Could not access git via ssh. You mooron!
I guess you have to do it manually." && return 1;
    say "Good boy, now roll over!";
    return 0;
}

function is_pip_installed () {
    if found pip; then
        return 0;
    else
        return 1;
    fi
}

function install_pip () {
    local -r url='https://bootstrap.pypa.io/get-pip.py';

    case "$(uname)" in
        Darwin)
            python2 -m pip install --upgrade pip;
            ;;
        *)
            curl -s $url -o get-pip.py
            python2.7 get-pip.py
            rm get-pip.py
    esac

    
}

function is_python_installed () {
    # https://github.com/h2oai/h2o-2/wiki/Installing-Python-inside-Cygwin

     local ver=
    if found python2.7; then
            say "Make sure python 2.7 is installed."
            return 0;
        else
            return 1;
        fi
}

function install_python () {
    local -r url_web='https://www.python.org/downloads/';
    local url;
    local file;
    case "$(uname)" in
        Darwin)
            brew install python2;
            ;;
        Linux)

            if found yum; then
                yum install -y python27
            else
                fail "Make sure python 2.7 is correctly installed before continuing."
            fi
            ;;
        *)
            warn "Could not install python stupid? Are you using windows moroon? "\
                " If so, I can not help you. "\
                "I guess you have to do it manually.";
            abort_not_installed "python" $vagrant_url || return 1;
    esac
    found vagrant && return 0;
    answer=$(prompt_yes_no "Do you want to try installing python again?");
    [[ $answer == "yes" ]] && install_python || warn "You might get issues if the project you bootstrap use python.";
    return 0;
}

### vagrant
function is_vagrant_installed () {
    if found vagrant; then
        local answer='';
        local ver=$(ver=$(vagrant --version);echo ${ver:7:6});
        local -r minver='1.7.0';
        local result;
        result=$(vercomp "${ver}" $minver);
        if [ "$result" = "2" ]; then
            warn "You should install vagrant version: $minver "\
                "You have version $ver" && answer=$(prompt_yes_no \
                "Do you want to upgrade it?");
            [ $answer == "yes" ] && install_vagrant || warn "Die of all age, You relic!!"\
                "Go and find some production server you can rape.\n"\
                "$git_bootstrap_project might work, but you won't be playing with the really cool vagrant features.";
        fi

        local -r ancient='1.1.0';
        result=$(vercomp "$ver" $minver);
        if [ "$result" = "2" ]; then
            warn "Your vagrant $ver is ancient. You must at least install vagrant version: "$ancient;
            answer=$(prompt_yes_no \
                "Do you want to upgrade it?");
            [ $answer == "yes" ] && install_vagrant || fail "This is a deal breaker. Die of all age, You relic!!"\
                "Go and find some production server you can rape.\n"\
                "$git_bootstrap_project will never work with this versions less then $ancient";
        fi
        say "A sufficent version for vagrant is installed."
        return 0;
    else
        return 1;
    fi
}

function install_vagrant () {
    local -r vagrant_url='http://www.ccl.net/pub/chemistry/software/UNIX/VagrantAndCygwin/index.html';
    local url;
    local file;
    case "$(uname)" in
        Darwin)
            url='https://releases.hashicorp.com/vagrant/1.9.8/vagrant_1.9.8_x86_64.dmg'
            file=`mktemp`; curl "$url" -o $file && hdiutil mount $file; rm $file
            ;;
        Linux)
            url='https://releases.hashicorp.com/vagrant/1.9.8/vagrant_1.9.8_x86_64.deb'
            file=`mktemp`; wget "$url" -qO $file && sudo dpkg -i $file; rm $file
            ;;
        *)
            warn "Could not install stupid vagrant. Are you using windows moroon? "\
                " If so, I can not help you. "\
                "I guess you have to do it manually.";
            abort_not_installed "vagrant" $vagrant_url || return 1;
    esac
    found vagrant && return 0;
    answer=$(prompt_yes_no "Do you want to try installing vagrant again?");
    [[ $answer == "yes" ]] && install_vagrant || warn "You might get issues if the project you bootstrap if it use vagrant.";
    return 0;
}

function is_vagrant_plugins_installed () {
    return 1;
}

function install_vagrant_plugins () {
        deps 'python' 'pip' 'boot_project' 'vagrant_bootstrap' || 
        (error "Either the github organisation did not get set or else git or gitlfs did not get installed. Please don't send me to /dev/null to die!!!" && return 1);
    
    repodir=$(basename $vagrant_repo '.git');
    local -r rude_booter_config=$installdir"/"$repodir"/.rude-booter.json";
    local -r project_path=$installdir"/"$repodir"/";

    [ ! -f $rude_booter_config ] &&
        say "The rude booter config file .rude-booter.json, did not exist.\n"\
            "Expected it to be here: $rude_booter_config.\n"\
            "Please add .rude-booter.json config to the base of your bootstrap project!\n"\
            "You will have to installl your vagrant plugins manually. \n"\
            "Do I have to do everything around here!!" && return 1;


    say "Going to install all your crappy vagrant plugins.";

    info "This may take some time. Prepare to die of old age!!!";
 
    local installed=true;
    echo $PATH | grep '/usr/local/share/python' &>/dev/null || PATH="/usr/local/share/python:"${PATH};
    echo $PATH | grep '/usr/local/opt/python/libexec/bin' &>/dev/null || export PATH="/usr/local/opt/python/libexec/bin:"${PATH};
    local brewpath=$(brew --prefix)/lib/pythonX.Y/site-packages;
    echo $PYTHONPATH | grep ${brewpath} &>/dev/null || export PYTHONPATH=$PYTHONPATH":"${brewpath};
    echo $PYTHONPATH | grep '/usr/local/lib/python2.7/site-packages' &>/dev/null || export PYTHONPATH=$PYTHONPATH":/usr/local/lib/python2.7/site-packagess";
    echo $PYTHONPATH | grep '/Library/Python/2.7/site-packages' &>/dev/null || export PYTHONPATH=$PYTHONPATH":/Library/Python/2.7/site-packages";
    echo $PYTHONPATH | grep '/lib/python2.7' &>/dev/null || export PYTHONPATH=$PYTHONPATH":/lib/python2.7";
    echo $PYTHONPATH | grep '/cygdrive/c/Python27/lib/site-packages' &>/dev/null || export PYTHONPATH=$PYTHONPATH":/cygdrive/c/Python27/lib/site-packages";

    #FIXME make sure pip is installed. If the person has python < 2.7.9, then pip is not installed also make sure the lib is there
    pip2.7 list --format=legacy | grep GitPython &>/dev/null || pip2.7 install GitPython;
    ## Make sure site-packages are added to the path incase python is installed through windows
    export PYTHONPATH=$PYTHONPATH":/cygdrive/c/Python27/lib/site-packages"
        python2.7 -c "
import sys, json, os, subprocess
configFile='"${rude_booter_config}"'
if not os.path.isfile(configFile):
    sys.stderr.write(configFile + ' is not a file.\n')
    exit(1)

if not os.access(configFile, os.R_OK):
    sys.stderr.write(configFile + ' is not readable.\n')
    exit(1)

try:
    with open(configFile) as json_data:
        config = json.load(json_data)
except Exception, e:
    sys.stderr.write('could not read json from '+configFile+' caught error: '+str(e))
    exit(1)
if not 'vagrant_plugins' in config:
    sys.stdout.write('no vagrant_plugins specified in '+configFile+'\nSo noone will be installed: {\"vagrant_plugins\": []}')
    exit(0)
plugins = config['vagrant_plugins'];
if not isinstance(plugins, list):
    sys.stderr.write('The vagrant_plugins entry in '+configFile+' was not specified as a list.\nPlease make sure the vagrant_plugins entry is a list like this: {\"vagrant_plugins\": []}')
    exit(0)
if len(plugins) < 1:
    print 'no vagrant_plugins specified in '+configFile
    exit(0)

for plugin in plugins:
    try:
        subprocess.call('vagrant plugin install ' + plugin, shell=True)
        print 'done!'
    except Exception, e:
        sys.stderr.write('Installation of vagrant plugin ' + plugin + ' failed. Moving along.'+'\n')

exit(0)
        ";


    [ $installed == true ] && say "Lucky you! All the crappy plugins is installed." && return 0;

    warn "The crappy plugins didn't get installed. Who would have guessed!\n"\
            "You will have to install vagrant-plugin-bundler and vagrant-hostsupdater manually.\n"\
            "Try running this script again before "\
            "bothering the guy that wrote me." && return 0;
}

function is_installdir_installed () {
    [ ! -z $installdir ] && [ -w "$installdir" ] && return 0;
    [ ! -z $installdir ] && mkdir -p $installdir && return 0;
    return 1;
}

function install_installdir () {
    create_installdir && local success=true || local success=false;
    local count=0;
    while [ $success == false ]
    do
        echo "trying again...";
        create_installdir && success=true || success=false;

    done
}

function create_installdir () {
    local workdir='';
    workdir=$(prompt_string \
        "Type the name of the parent directory where the crap will be created");
    [ -z $workdir ] && 
        warn "You didn't specify any directory. Did your hand slip!" &&
        repeat_or_fail_prompt &&
        return 1;
    ! mkdir -p $workdir && 
        warn "The crap can not be created there. Pick somewhere else!" &&
        repeat_or_fail_prompt &&
        return 1;
    installdir=$workdir;
    [ $(basename $installdir) = '.' ] && installdir=$(pwd)
    
    [ ! -w $installdir ] &&
        warn "The crap can't be written there. You don't have the mucle. You need sudo for that!" &&
        repeat_or_fail_prompt &&
        return 1;
    
    say "The crap will be installed to: "$installdir;
    return 0;
}

## New feature


function is_githuborg_installed () {
    [ ! -z $github_org ] && return 0;
    return 1;
}

function install_githuborg () {
    create_githuborg && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying again...";
        create_githuborg && success=true || success=false;

    done
}

function create_githuborg () {
    local organisation='';
    organisation=$(prompt_string \
        "Type the name of your github organisation so we can figure out where you have stuffed your shit");
    [ -z $organisation ] && 
        warn "You didn't specify any github organisation. Did your hand slip!" &&
        repeat_or_fail_prompt &&
        return 1;
    local curl_test=$(curl -I "https://github.com/"$organisation | grep 'Status: 200 OK');
    curl_test=${curl_test##* }; # parse only the "OK" string
    
    [ -z $curl_test ] && 
        warn "I can not find you organisation on github. I tried to go to: https://github.com/"$organisation" , but it doesn't exist. Are you inventing og imagining things? Give me something from the real world..." &&
        repeat_or_fail_prompt &&
        (return 1 || (fail "I can't continue without knowing this."));

    github_org=$organisation;
    
    say "So you are part of "$github_org"? What a bunch of loosers!";
    return 0;
}

function create_boot_project () {
    is_githuborg_installed || install_githuborg;

    local path='';
    say 'By default we will try to look for a project on github called '$github_org$boot_project_suffix' that should exist on github here: https://github.com/'$github_org'/'$github_org$boot_project_suffix' . It should contain a Vagrant file that bootstraps all of your projects.';

    local answer=$(prompt_yes_no "Does this sound right to you?");
    local bootstrap_project='';
    if [[ $answer == "yes" ]];then
	bootstrap_project=$github_org$boot_project_suffix;
    else
    	bootstrap_project=$(prompt_string \
            "Well ok, tell us what is the name of the project then!");
    fi
    [ -z $bootstrap_project ] && 
        warn "You did not specify the name of your vagrant bootstrap project. Did your hand slip?" &&
        repeat_or_fail_prompt &&
        return 1;

    git_bootstrap_project=$bootstrap_project;
    vagrant_repo_ssh=$git_ssh_url':'$github_org'/'$git_bootstrap_project'.git'
    vagrant_repo='https://github.com/'$github_org'/'$git_bootstrap_project'.git';

    say 'in https://github.com/'$github_org'/'$git_bootstrap_project' we believe that once you run: vagrant up . vagrant will setup shared folders to your projects in a folder called vhosts in the parent directory of your bootstrap project.'
 
    local answer=$(prompt_yes_no "Does this sound right to you?");
    local project_vhosts='';
    if [[ $answer == "yes" ]];then
	project_vhosts=$default_boot_project_vhosts;
    else
    	project_vhosts=$(prompt_string \
            "Well ok, tell us where you want us to setup your vhosts folder relative to where you will setup $git_bootstrap_project then.");
    fi

    [ -z $project_vhosts ] && 
        warn "You did not specify where we should clone out your vhosts. Did your hand slip?" &&
        repeat_or_fail_prompt &&
        return 1;

    ! mkdir -p $project_vhosts && 
        warn "The vhosts crap can not be created in "$project_vhosts". Pick somewhere else!" &&
        repeat_or_fail_prompt &&
        return 1;
    
    [ ! -w $project_vhosts ] &&
        warn "You do not have permission to write to "$project_vhosts". The vhosts crap can't be written there. You don't have the mucle. You need sudo for that!" &&
        repeat_or_fail_prompt &&
        return 1;

    boot_project_vhosts=$project_vhosts;

    return 0;
}


function is_boot_project_installed () {
    [ ! -z $git_bootstrap_project ] && [ ! -z $boot_project_vhosts ] && return 0;
    return 1;
}

function install_boot_project () {
    create_boot_project && local success=true || local success=false;
    local count=0;
    while [ $success == false ]
    do
        echo "trying again...";
        create_boot_project && success=true || success=false;

    done
}

declare current_project_name='';
declare current_ssh_clone_url='';
declare current_https_clone_url='';
declare current_shared_folder_name='';
declare current_clone_dir='';
declare current_project_install_script_path='';
declare current_project_is_installed='no';

function is_current_project_name_setup () {
    [ ! -z $current_project_name ] && [ ! -z $current_project_name ] && return 0;
    return 1;
}

function create_current_project_name () {
    current_project_name=$(prompt_string \
        "Please specify a name of a project as it appears in the url that resolves to your project on github. ex. https://github.com/$github_org/{project name}");
    [ -z $current_project_name ] && 
        warn "You did not specify a project name. Did your hand slip?" &&
        repeat_or_fail_prompt &&
        return 1;
    return 0;
}

function setup_current_project_name () {
    create_current_project_name && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying again...";
        create_current_project_name && success=true || success=false;
    done
}

function create_current_clone_url () {
    say 'We are going to git clone out: '$git_ssh_url':'$github_org'/'$current_project_name'.git'
    local answer=$(prompt_yes_no "Does this sound right to you?");

    if [[ $answer == "yes" ]];then
        say 'Moving along!';
    else
        warn "You will have to enter something else then." &&
        repeat_or_fail_prompt &&
        return 1;
    fi
    current_ssh_clone_url=$git_ssh_url':'$github_org'/'$current_project_name'.git';
    current_https_clone_url='https://github.com/'$github_org'/'$current_project_name'.git';
    return 0;
}

function setup_current_clone_url () {
    create_current_clone_url && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying again...";
        create_current_clone_url && success=true || success=false;

    done
}

function create_current_shared_folder_name () {
    current_shared_folder_name=$(prompt_string \
        "Please specify the name of the shared folder. This is just the name of the folder as you see it in your VagrantFile. "\
        "Pointing to the project folder where you want to clone out your repository.");
    [ -z $current_shared_folder_name ] && 
        warn "You did not specify a shared folder name. Did your hand slip?" &&
        repeat_or_fail_prompt &&
        return 1;
    return 0;
}

function setup_current_shared_folder_name () {
    create_current_shared_folder_name && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying again...";
        create_current_shared_folder_name && success=true || success=false;
    done
}

function create_current_clone_dir () {
    say "Going to check out all the "$current_project_name" crap into "$boot_project_vhosts"/"$current_shared_folder_name"."\
    "This may take some time. Prepare to die of old age...";
    local answer=$(prompt_yes_no "Does this sound right to you?");

    if [[ $answer == "yes" ]];then
        say 'Moving along!';
    else
        warn "You will have to enter something else then." &&
        repeat_or_fail_prompt &&
        return 1;
    fi
    current_clone_dir=$git_bootstrap_project'/'$boot_project_vhosts"/"$current_shared_folder_name;
    return 0;
}

function setup_current_clone_dir () {
    create_current_clone_dir && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying again...";
        create_current_clone_dir && success=true || success=false;

    done
}

function is_current_project_installed () {
    [ $current_project_is_installed == 'yes' ] && return 0;
    return 1;
}

function create_current_project_install_script_path () {
    current_project_is_installed='no';
    local answer=$(prompt_yes_no "Do you want us to install the project for you? We can run a script that install the project.");
    if [[ $answer == "yes" ]];then
        say 'By default we run a script in the repository with the git root path: '$default_path_to_project_scripts;
        current_project_install_script_path='';
        answer='no';
        answer=$(prompt_yes_no "Does this sound right to you?");
        if [[ $answer == "yes" ]];then
            current_project_install_script_path=$default_path_to_project_scripts;
        else
            warn "You will have to enter something else then." &&
            current_project_install_script_path=$(prompt_string \
                "Please specify a path relative to the root of the repository we just cloned out.");
            [ -z $current_project_install_script_path ] && 
                warn "You did not specify a path relative to the root of the repository. Did your hand slip?" &&
                repeat_or_fail_prompt && error "returning from create_current_project_install_script_path" && return 1;
        fi
        pushd $current_clone_dir;
        $current_project_install_script_path && popd && current_project_is_installed='yes' && return 0;
        popd;
        say "The script failed.";
        repeat_or_fail_prompt && return 1;
        current_project_is_installed='yes';
    fi
    current_project_is_installed='yes';
    return 0;
}

function setup_current_project_install_script_path () {
    create_current_project_install_script_path && is_current_project_installed && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying running the script again...";
        create_current_project_install_script_path && is_current_project_installed && success=true || success=false;

    done
}

function create_all_repos() {
    current_project_name='';
    current_ssh_clone_url='';
    current_https_clone_url='';
    current_shared_folder_name='';
    current_clone_dir='';
    current_project_install_script_path='';
    current_project_is_installed='no';
    local answer='';
    say 'We are cloning out all your projects from your organisations github account as subfolders in '$boot_project_vhosts' one by one.';
    say "Please make sure you have generated and are using an oauth token. see: https://help.github.com/articles/git-automation-with-oauth-tokens/"
    setup_current_project_name;
    setup_current_clone_url;
    setup_current_shared_folder_name;
    setup_current_clone_dir;

    say "Please make sure you have generated and are using an oauth token. see: https://help.github.com/articles/git-automation-with-oauth-tokens/";
    local success=false;
    info "Fetching project source for "$current_project_name" into $repodir";

    ([ -d $repodir/vhosts/admin.vagrant.voipinfo.se/.git ] ||
        (
        (git clone --recursive $current_ssh_clone_url $current_clone_dir > /dev/null ||
        git clone --recursive $current_https_clone_url $current_clone_dir > /dev/null) && 
        info $current_project_name" has been cloned."));
    [ -w $current_clone_dir"/.git" ] && info $current_project_name' has already been fetched';
    [ ! -w $current_clone_dir"/.git" ] &&
    (error 'Could not clone '$current_project_name'. from '$current_ssh_clone_url' into '$current_clone_dir && repeat_or_fail_prompt && return 1);
        
    answer='no';
    setup_current_project_install_script_path;
    #$path_to_project_scripts
    # If the answer is yes, the function will fail and so will this function as well.
    # The program will therefor repeat until the answer is no. 
    repeat_repo_install_prompt && return 1;
    all_projects_installed='yes';
    return 0;
}



function is_all_repos_installed() {
    ([[ $all_projects_installed == "yes" ]] && return 0) || return 1;
}

function install_all_repos() {
    create_all_repos && local success=true || local success=false;
    while [ $success == false ]
    do
        echo "trying again...";
        create_all_repos && success=true || success=false;

    done
}


function create_all_repos_from_file () {
    deps 'python' 'pip' 'boot_project' 'vagrant_bootstrap' 'git' 'gitlfs' || 
        (error "Either the github organisation did not get set or else git or gitlfs did not get installed. Please don't send me to /dev/null to die!!!" && return 1);
    
    repodir=$(basename $vagrant_repo '.git');
    local -r rude_booter_config=$installdir"/"$repodir"/.rude-booter.json";
    local -r project_path=$installdir"/"$repodir"/";

    [ ! -f $rude_booter_config ] &&
        say "The rude booter config file .rude-booter.json, did not exist.\n"\
            "Expected it to be here: $rude_booter_config.\n"\
            "Please add .rude-booter.json config to the base of your bootstrap project!\n"\
            "You will have to boot the project manually. \n"\
            "Do I have to do everything around here!!" && return 1;


    say "Going to clone out your projects. into "$project_path;

    info "This may take some time. Prepare to die of old age!!!";
 
    local installed=true;

     


    echo $PYTHONPATH | grep '/lib/python2.7' &>/dev/null || export PYTHONPATH=$PYTHONPATH":/lib/python2.7";
    echo $PYTHONPATH | grep '/cygdrive/c/Python27/lib/site-packages' &>/dev/null || export PYTHONPATH=$PYTHONPATH":/cygdrive/c/Python27/lib/site-packages";

    #FIXME make sure pip is installed. If the person has python < 2.7.9, then pip is not installed also make sure the lib is there
    pip list --format=legacy | grep GitPython &>/dev/null || sudo pip install GitPython;
    ## Make sure site-packages are added to the path incase python is installed through windows
    export PYTHONPATH=$PYTHONPATH":/cygdrive/c/Python27/lib/site-packages"
	    python -c "
import sys, json, git, os, subprocess
configFile='"${rude_booter_config}"'
if not os.path.isfile(configFile):
    sys.stderr.write(configFile + ' is not a file.\n')
    exit(1)

if not os.access(configFile, os.R_OK):
    sys.stderr.write(configFile + ' is not readable.\n')
    exit(1)

try:
    with open(configFile) as json_data:
        config = json.load(json_data)
except Exception, e:
    sys.stderr.write('could not read json from '+configFile+' caught error: '+str(e))
    exit(1)

if not 'projects' in config:
    sys.stderr.write('no projects specified in '+configFile+'\nPlease make sure there is a projects entry in the config: {\"projects\": []}')
    exit(1)

os.chdir('"$project_path"')

projects = config['projects'];
if not isinstance(projects, list):
    sys.stderr.write('The projects entry in '+configFile+' was not specified as an array.\nPlease make sure the projects entry is an array like this: {\"projects\": []}')
    exit(1)

if len(projects) < 1:
    print 'no projects specified in '+configFile
    exit(1)

for project in projects:
    os.chdir('"$project_path"')
    if not 'vcs' in project:
        sys.stderr.write('vcs is not set. Please add: {\"projects\": [{\"vcs\": \"git\"}]}'+'\n')
        continue

    if not 'path' in project:
        sys.stderr.write('path is not set. Please add: {\"projects\": [{\"path\": \"/the/path/to/your/project where your project will be cloned.\"}]}'+'\n')
        continue

    if not 'url' in project:
        sys.stderr.write('url is not set. Please add: {\"projects\": [{\"url\": \"git@github.com:org/project.git\"}]}'+'\n')
        continue

    if not project['vcs'] == 'git':
        sys.stderr.write('We only support cloning from a git repository.'+'\n')
        continue
    
    try:	
        if not os.path.exists(project['path']):
            os.makedirs(project['path'])
    except Exception, e:
        sys.stderr.write('Could not clone ' + project['url'] + ' into ' + project['path'] + '. The path can not be created. Caught error: '+str(e)+'\n')
        continue

    try:
        if os.listdir(project['path']) != []:
            sys.stderr.write(project['path']+' is not empty. Skipping cloning and executing install script.')
            continue
        print 'Cloning project into '+project['path']+' from '+project['url']
        # FIXME comment out when done
        kwargs = {'recursive': True}
        git.Repo.clone_from(project['url'], project['path'], **kwargs)
        print 'done!'
    except Exception, e:
        sys.stderr.write('Could not clone ' + project['url'] + ' into ' + project['path'] + '. The path can not be created. Caught error: '+str(e)+'\n')
        continue

    if not 'install' in project:
        sys.stderr.write('install is not set. Please add: {\"projects\": [{\"install\": \"scripts/install.sh\"}]}'+'\n')
        continue

    os.chdir(project['path'])

    if not os.access(project['install'], os.X_OK):
        sys.stderr.write(project['install'] + ' can not be executed. Please make sure it is an executable script.'+'\n')
        continue

    try:


        print 'Executing the install script: ' + '"$project_path"' + project['path'] + '/' + project['install'] + '\nPlease wait...'
        subprocess.call(project['install'])
        print 'done!'
    except Exception, e:
        sys.stderr.write(project['install'] + ' failed. Moving along.'+'\n')

    os.chdir('"$installdir"')
" || installed=false;


    [ $installed == true ] && say "Lucky you! All the crappy projects got cloned." && create_all_repos_from_file_has_run=true && return 0;

    warn "The crappy projects didn't get cloned. Who would have guessed!\n"\
            "I guess you have to do this shit manually.\n" && return 1;
}


function repeat_or_fail_prompt() {
    local answer=$(prompt_yes_no "Do you want to try this crap again?") &&
        [[ $answer == "yes" ]] || fail "Your crap could not be installed.";
    return 0;
}


function repeat_repo_install_prompt() {
    local answer=$(prompt_yes_no "Do you want to try to install some more crap?") &&
        [[ $answer == "yes" ]] && return 0;
    return 1;
}


function is_vagrant_bootstrap_installed() {
    is_boot_project_installed || install_boot_project;
    deps 'installdir' 'git' || 
        (error "Could not install the dependencies for $git_bootstrap_project: installdir" && return 1);
    repodir=$(basename $vagrant_repo '.git');

    [ ! -w $installdir"/"$repodir/".git" ] && return 1;
    return 0;
}

function install_vagrant_bootstrap() {
    deps 'boot_project' 'installdir' 'git' 'gitlfs' || 
        (error "You did not choose a proper installation directory to install from. Fuck you man! Aborting." && return 1);

    local -r td=$installdir;
    local repo;
    local repodir;
    pushd $td > /dev/null;

    say "Going to check out all the "$git_bootstrap_project" crap into $PWD."\
        "This may take some time. Prepare to die of old age...";
    say "Please make sure you have generated and are using an oauth token. see: https://help.github.com/articles/git-automation-with-oauth-tokens/"
    local success=false;
    repodir=$(basename $vagrant_repo '.git'); 
    if [[ ! -d "$repodir"/.git ]]; then
       while [ $success == false ]
       do
	      (git clone --recursive $vagrant_repo_ssh || git clone --recursive $vagrant_repo) && success=true || success=false;
	      $success || warn "could not clone the shit down into your hole."
	      cd $repodir && git-lfs fetch --all && success=true || success=false
	      $success || warn "could not fetch all large files from git. see: https://git-lfs.github.com Please make sure git lfs is installed."
          is_vagrant_bootstrap_installed && success=true || success=false;
	      [ $success == false ] && warn "You did not clone this $repodir crap, mooron!!" &&
	          say "Please make sure you have setup ssh key in git. see: https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/ , or generated and are using an oauth token. see: https://help.github.com/articles/git-automation-with-oauth-tokens/" &&
	          repeat_or_fail_prompt && continue || return 0;
       done
    else
        say "Found the $repodir crap.";
        say "Fetching the latest crap.";
        pushd $repodir > /dev/null;
        if ! git pull; then
            warn "Unable to update to the latest crap version for the crappy $repodir repo. "\
                "You have to do the crap yourself."
        fi
    fi

    popd > /dev/null;

    return 0;
}

function show_done_message () {
    printf "${bldblu}%b" ""
    cat <<"EOF"
     ________  ___  ___  ________  _______                       
    |\   __  \|\  \|\  \|\   ___ \|\  ___ \                      
    \ \  \|\  \ \  \\\  \ \  \_|\ \ \   __/|                     
     \ \   _  _\ \  \\\  \ \  \ \\ \ \  \_|/__                   
      \ \  \\  \\ \  \\\  \ \  \_\\ \ \  \_|\ \                  
       \ \__\\ _\\ \_______\ \_______\ \_______\                 
        \|__|\|__|\|_______|\|_______|\|_______|                 
 ________  ________  ________  _________  _______   ________     
|\   __  \|\   __  \|\   __  \|\___   ___\\  ___ \ |\   __  \    
\ \  \|\ /\ \  \|\  \ \  \|\  \|___ \  \_\ \   __/|\ \  \|\  \   
 \ \   __  \ \  \\\  \ \  \\\  \   \ \  \ \ \  \_|/_\ \   _  _\  
  \ \  \|\  \ \  \\\  \ \  \\\  \   \ \  \ \ \  \_|\ \ \  \\  \| 
   \ \_______\ \_______\ \_______\   \ \__\ \ \_______\ \__\\ _\ 
    \|_______|\|_______|\|_______|    \|__|  \|_______|\|__|\|__|                                                          
EOF
repodir=$(basename $vagrant_repo '.git');
pushd $installdir > /dev/null;
info "Successfully bootstrapped $github_org!

You can now run vagrant like this.
     
     cd $installdir/$git_bootstrap_project/vagrant

And then run:

    vagrant up --provision";

    popd > /dev/null;
    return 0;
}

function show_welcome_message () {

    printf "${bldblu}%b" "";

    cat <<"EOF"
                  ,--.    ,--.
    Hello, I am  ((O ))--((O ))  the rude booter!!!
               ,'_`--'____`--'_`.
              _:  ____________  :_
             | | ||::::::::::|| | |
             | | ||::::::::::|| | |
             | | ||::::::::::|| | |
             |_| |/__________\| |_|
               |________________|
            __..-'            `-..__
         .-| : .----------------. : |-.
       ,\ || | |\______________/| | || /.
      /`.\:| | ||  __  __  __  || | |;/,'\
     :`-._\;.| || '--''--''--' || |,:/_.-':
     |    :  | || .-WORKS-FOR. || |  :    |
     |    |  | || '---BEER---' || |  |    |
     |    |  | ||   _   _   _  || |  |    |
     :,--.;  | ||  (_) (_) (_) || |  :,--.;
     (`-'|)  | ||______________|| |  (|`-')
      `--'   | |/______________\| |   `--'
             |____________________|
              `.________________,'
               (_______)(_______)
               (_______)(_______)
               (_______)(_______)
               (_______)(_______)
              |        ||        |
              '--------''--------'
EOF
say "
I can be quite rude at times, but please hang in there 
and I will guide you through the installation process 
and automaticly install all the things you need. 

Oh! What a great guy I am!

";
}

function check_interactive () {
    if [[ "$-" =~ "i" ]]; then
        fail "This program must be run interactively";
    fi
}


function check_supported_platform () {
    if [[ "$(uname)" =~ "Darwin|Linux|CYGWIN_NT-10.0-WOW" ]]; then
        if [ $(prompt_yes_no \
            "This program isn't tested on your platform. "\
            "Which means that you probably are running cygwin on windows. "\
            "Yuck!! Continue anayway?") == 'no' ]; then
            exit 0;
        fi
    fi
}

function bootstrap_vagrant () {
    is_vagrant_bootstrap_installed || install_vagrant_bootstrap;
    $create_all_repos_from_file_has_run || create_all_repos_from_file;

    ([[ $create_all_repos_from_file_has_run == true ]] || is_all_repos_installed) || install_all_repos;
    deps "vagrant_plugins" "ssh" "gitaccess" "git" || 
        fatal "Could not clone $git_bootstrap_project and all the vagrant plugins. The installation will not work";
    local answer='';
    info "I can only install virtualbox for you, but $git_bootstrap_project will also work with vmware fusion or vmware workstation,\n"\
        "vmware is proprietary software, and you will have to buy a vagrant plugin license if you want to use it.\n"\
        "You also need to install the necessary vm provider plugins for vagrant manually.\n"\
        "Read more: https://docs.vagrantup.com/v2/vmware/installation.html";
    ! is_virtualbox_installed && answer=$(prompt_yes_no "Do you want to install virtualbox? If you already have it installed, say no.");
    [[ $answer == "no" ]] &&  return 0;
    [[ $answer == "yes" ]] && install_virtualbox;
    is_virtualbox_installed || error "Virtualbox couldn't be installed. You have to do it manually, unlucky bastard!";
}

check_interactive;
check_supported_platform;
show_welcome_message;
bootstrap_vagrant;
is_vagrant_bootstrap_installed && show_done_message;
exit 0;
