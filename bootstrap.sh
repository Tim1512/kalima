#!/bin/bash

#DESCRIPTION: Creation script for Kalima.

#!/bin/sh

verbose=

case "$1" in
-v|--v|--ve|--ver|--verb|--verbo|--verbos|--verbose)
    verbose=1
    shift ;;
esac

if [ "$verbose" = 1 ]; then
    exec 4>&2 3>&1
else
    exec 4>/dev/null 3>/dev/null
fi

# echo "verbose" >&3
# echo "normal"

SCRIPTPATH=$(dirname $(readlink -f $0))
INSTALLPATH="/usr/share/kalima"
BINPATH="/usr/bin/kalima"

echoError() {
  RED='\033[0;31m'
  NC='\033[0m' # No Color
  printf "${RED}[!]${NC} $1\n"
}
echoInfo() {
  YELLOW='\033[0;33m'
  NC='\033[0m' # No Color
  printf "${YELLOW}[i]${NC} $1\n"
}
echoAction() {
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color
  printf "${GREEN}[+]${NC} $1\n"
}
echoSection() {
  CYAN='\033[0;36m'
  NC='\033[0m' # No Color
  printf "${CYAN}$1${NC}\n"
}


function VMWAREmountShare () {

  #Are we in VMWare? -  Mount the VMWare Shared Folders
if [ $(which vmhgfs-fuse) ]; then
  ([ $(vmware-hgfsclient) == $project_name ]) >&3
  ERROR=$?
  if [ $ERROR -ne 0 ]; then
     echoError "Please make sure '$project_name' is an actual Shared Folder in VMWare."
     exit
   else
     [ ! -d  $project_home ] && mkdir "$project_home"
     vmhgfs-fuse -o auto_unmount .host:/$project_name $project_home
     echoAction "Mounting $project_home"
     sleep 2
     
     echoAction "Making project file structure @ '$project_home'"
     mkdir -p "$project_home/0_logs/" "$project_home/1_evidence/" "$project_home/2_scripts/" "$project_home/3_downloads/" "$project_home/4_random/" "$project_home/5_notes/" >&3

     echoAction "Enabling auto-mount of '$project_home' at boot time"
(mkdir ~/.config/autostart ; \
 echo "[Desktop Entry]
      Encoding=UTF-8
      Version=0.9.4
      Type=Application
      Name=vmhgfs-fuse
      Comment=VMWare Shared Folders
      Exec=vmhgfs-fuse -o auto_unmount,nonempty .host:/$project_name $project_home
      OnlyShowIn=XFCE;
      RunHook=0
      StartupNotify=false
      Terminal=false
      Hidden=false" > ~/.config/autostart/vmhgfs-fuse.desktop) >&3
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Auto-mount could not be enabled"
fi
  
  fi

else
  echo "This project was designed with VMWare in mind, if you're using something else tweak the code! I'm going to give up now..."
  exit
fi

}


echoSection "===== + Building + ====="

# Check sudo
sudo -v

# ensure this is the right kali version (2020.1)
if [ $(lsb_release -r | awk -F" " '{ print $2 }') ==  "2020.1" ]; then
   echoInfo "This is Kali 2020.1..."
else
   echoError "This has been tested on Kali 2020.1 only... bye!"
   exit 1
fi

echoAction "Randomizing MAC address (on eth0)"
sudo macchanger -r eth0 >&3

echoAction "Performing 'apt update'"
sudo apt-get -y update >&3


if [ ! -d  $INSTALLPATH ]; then
   echoAction "Creating sctipt structure @ '$INSTALLPATH'";
   sudo mkdir $INSTALLPATH >&3
   sudo cp -R $SCRIPTPATH/scripts $INSTALLPATH >&3
   #sudo chmod +x $INSTALLPATH/scripts/*
fi


echoAction "Asking bootstrap questions"
if [ ! -f $INSTALLPATH/project_name ]; then
   read -p 'Project codename: ' project_name 
   sudo bash -c "echo $project_name > $INSTALLPATH/project_name"
 
   project_home=$HOME/$project_name
   sudo bash -c "echo $project_home > $INSTALLPATH/project_home"
else
   project_name=$(cat $INSTALLPATH/project_name)
   project_home=$(cat $INSTALLPATH/project_home)
fi


if [ ! -f $INSTALLPATH/kalima_hostname ]; then

   read -p 'Kali hostname: ' hostnameVar
   sudo bash -c "echo $hostnameVar > $INSTALLPATH/kalima_hostname"

else
   hostnameVar=$(cat $INSTALLPATH/kalima_hostname)
fi

if [ ! -f ~/.cobaltstrike.license ]; then

   read -p 'Cobalt Strike key: ' CSKEY
   echo $CSKEY > ~/.cobaltstrike.license
else
  CSKEY=$(cat ~/.cobaltstrike.license)
fi

if [ "$(sudo chage -li $USER | grep "Last password change" | awk -F":" '{print $2}' | xargs)" != "$(date '+%Y-%m-%d')" ]; then
   sudo passwd $USER
fi



echoAction "Creating script loader @ '$BINPATH'"

echo "#!/bin/bash
function usage() {
  echo \"
  Kalima - Evil Evil stuff!

  Usage: \$0 [options]

OPTIONS:
\"
cd $INSTALLPATH/scripts
ls -1A | while read file; do echo -e \"\$file \n\t \$(grep \"#DESCRIPTION:\" \$file | sed 's/#DESCRIPTION: //g')\";done
cd - > /dev/null 2>&1
}
if [ -f $INSTALLPATH/scripts/\$1 ] 
  then
    bash $INSTALLPATH/scripts/\$@
  else
    usage
    exit 1
fi
" > $SCRIPTPATH/kalima-script.sh
sudo bash -c "mv $SCRIPTPATH/kalima-script.sh $BINPATH"
sudo chmod +x $BINPATH

echoAction "Cleaning up useless directories"
rm -rf ~/Desktop ~/Documents ~/Music ~/Pictures ~/Public ~/Templates ~/Videos >&3
mkdir -p ~/Tools ~/Tools/nse >&3


(mount | grep -o $project_name) >&3
  ERROR=$?
  if [ $ERROR -ne 0 ]; then
     VMWAREmountShare
   else
     echoAction "All data should be stored under $project_home."
  fi



echoAction "Installing Sublime Text 3"
(wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -;apt -qqq install apt-transport-https;echo "deb https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list;apt -qqq update;apt -qqq install sublime-text) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Sublime Text 3 could not be installed"
fi


exit 1

echoAction "Installing Oracle Java 8"
(wget -q -O java.tgz $(curl -s https://www.java.com/en/download/linux_manual.jsp | grep -E ".*x64.*javadl" | grep -v "RPM" | sed "s/.*href=\"//g;s/\".*//g" | head -n 1) && tar xzf java.tgz;javaver="$(tar tf java.tgz | head -n1 | tr -d "/")";[ ! -d /opt/java ] && mkdir /opt/java;mv $javaver /opt/java;update-alternatives --install "/usr/bin/java" "java" "/opt/java/$javaver/bin/java" 1;update-alternatives --set java /opt/java/$javaver/bin/java;rm java.tgz) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Java could not be installed"
fi


echoAction "Installing Cobalt Strike"
(wget -q https://www.cobaltstrike.com$(curl -s 'https://www.cobaltstrike.com/download' -XPOST -H 'Referer: https://www.cobaltstrike.com/download' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Origin: https://www.cobaltstrike.com' -H 'Host: www.cobaltstrike.com' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Connection: keep-alive' -H 'Accept-Language: en-us' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/604.3.5 (KHTML, like Gecko) Version/11.0.1 Safari/604.3.5' --data "dlkey=$CSKEY" | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep /downloads/ | cut -d '.' -f 1).tgz -O cobaltstrike.tgz;[ ! -d ~/Tools ] && mkdir ~/Tools;tar xzf cobaltstrike.tgz -C ~/Tools/ && rm cobaltstrike.tgz && cd ~/Tools/cobaltstrike && ./update && cd - 2>&1>/dev/null) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Cobalt Strike could not be installed"
   rm cobaltstrike.tgz
fi

echoAction "Installing various hacking tools"
(curl -sSL https://raw.githubusercontent.com/hdm/scan-tools/master/nse/banner-plus.nse > ~/Tools/nse/banner-plus.nse ; \
git clone https://github.com/bitsadmin/wesng.git ~/Tools/wesng; \
DEBIAN_FRONTEND=noninteractive apt -qqq install -y python3-impacket impacket-scripts seclists libnetfilter-queue1 asciinema python3-setuptools python3-distutils python3-pip bloodhound vlc ufw xclip terminator crackmapexec sslyze sslscan eyewitness gobuster build-essential; \
pip3 -q install pwntools; \
wget -q -O bettercap2.zip https://github.com$(curl -Ls https://github.com/bettercap/bettercap/releases/latest | grep -E -o '/bettercap/bettercap/releases/download/v[0-9.*]+/bettercap_linux_amd64_v[0-9.*]+zip' | head -n 1);[ ! -d ~/Tools/bettercap ] && mkdir ~/Tools/bettercap;unzip -qq bettercap2.zip -d ~/Tools/bettercap/;rm -rf bettercap2.zip;git clone -q https://github.com/bettercap/caplets.git ~/Tools/bettercap/caplets; \
sed -i 's/geteuid/getppid/' /usr/bin/vlc) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Hacking Tools could not be installed"
fi



echoAction "Installing Fish"
(apt -qqq update && apt -qqq install git fish python2 python3 curl tmux mosh golang pipenv python-pip -y && pip -q install virtualfish && chsh -s /usr/bin/fish) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Fish could not be installed"
fi

echoAction "Installing Fisher"
(gpg --keyserver hkp://pool.sks-keyservers.net:80 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB && curl -sSL https://get.rvm.io | bash -s stable && curl -s https://git.io/fisher --create-dirs -sLo ~/.config/fish/functions/fisher.fish && /usr/bin/fish -c "fisher add kennethreitz/fish-pipenv" && echo "set pipenv_fish_fancy yes" >> /root/.config/fish/config.fish) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Fisher could not be installed"
fi

echoAction "Installing Oh-My-Fish"
(git clone -q https://github.com/oh-my-fish/oh-my-fish /tmp/oh-my-fish && /tmp/oh-my-fish/bin/install --offline --noninteractive --yes && echo 'set -g VIRTUALFISH_PYTHON "/usr/bin/python"' >>  /root/.config/omf/before.init.fish && echo 'set -g VIRTUALFISH_PLUGINS "auto_activation"' >>  /root/.config/omf/before.init.fish && echo 'set -g VIRTUALFISH_HOME $HOME/.local/share/virtualenvs/' >>  /root/.config/omf/before.init.fish && echo "set -xg GOPATH $HOME/Tools/go" >>  /root/.config/omf/init.fish && fish -c "omf install extract rvm virtualfish") > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Oh-My-Fish could not be installed"
fi

echoAction "Installing Gyarados (Theme) for Oh-My-Fish"
(/usr/bin/fish -c "omf install https://github.com/rTD-JP/gyarados" && /usr/bin/fish -c "omf theme gyarados") > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Gyarados could not be installed"
fi

echoAction "Configuring terminator"
mkdir -p ~/.config/terminator
echo "[global_config]
[keybindings]
[profiles]
  [[default]]
    cursor_color = \"#aaaaaa\"
    use_custom_command = True
    custom_command = set -l recording (cat ~/.config/kalima/record_session); if test \"\$recording\" = \"true\"; clear && env ASCIINEMA_REC=1 asciinema rec (cat ~/.config/kalima/project_home)/1_evidence/screenshot_(date +%F_%H-%M-%S).cast; else; clear && exec fish; end;
  [[non-kalima]]
    cursor_color = \"#aaaaaa\"
[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
    [[[child1]]]
      type = Terminal
      parent = window0
      profile = default
      directory = /root
[plugins]" > ~/.config/terminator/config

ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Terminator could not be configured."
fi


echoAction "Adding Obey2 greeting"
(cp scripts/obey2 ~/.config/fish/obey2 && echo set fish_greeting >> ~/.config/fish/config.fish;echo "~/.config/fish/obey2" >> ~/.config/fish/config.fish;chmod +x ~/.config/fish/obey2) > /dev/null 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
   echoError "Obey2 could not be installed"
fi


WMver=$(echo "$XDG_DATA_DIRS" | grep -Eo 'xfce|kde|gnome')

if [ $WMver == "xfce" ]; then
    echoInfo "This is XFCE"
    
    echoAction "Configuring screen recording"
    sed -i "s,autosave_video_dir.*$,autosave_video_dir = $(cat ~/.config/kalima/project_home)/1_evidence/,g" ~/.config/kazam/kazam.conf
    sed -i 's/autosave_video =.*$/autosave_video = True/' ~/.config/kazam/kazam.conf

    echoAction "Configuring screenshots"
    xfconf-query -c xfce4-keyboard-shortcuts  -p /commands/custom/Print -s "xfce4-screenshooter -r -o /root/.config/kalima/scripts/screenshot"

    mkdir -p ~/.local/share/xfce4/helpers
    echo "[Desktop Entry]
    NoDisplay=true
    Version=1.0
    Encoding=UTF-8
    Type=X-XFCE-Helper
    X-XFCE-Category=TerminalEmulator
    X-XFCE-CommandsWithParameter=/usr/bin/terminator \"%s\"
    Name=kalima
    X-XFCE-Commands=/usr/bin/terminator
    Icon=kalima" > /root/.local/share/xfce4/helpers/custom-TerminalEmulator.desktop

    echo "TerminalEmulator=custom-TerminalEmulator" > /root/.config/xfce4/helpers.rc
    echo "false" > ~/.config/kalima/record_session
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/image-style -s 0
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVirtual1/workspace0/color-style -s 0
    xfconf-query -c xfce4-desktop --create -p /backdrop/screen0/monitorVirtual1/workspace0/rgba1 -s 0.000000 -s 0.000000 -s 0.000000 -s 1.000000  -t string -t string -t string  -t string

  elif [ $WMver == "gnome" ]; then
    echoInfo "This is GNOME"
    echoAction "Configuring screenshots"
    dconf write /org/gnome/gnome-screenshot/auto-save-directory "'file:///$project_home/1_evidence/'"
    dconf write /org/gnome/gnome-screenshot/last-save-directory "'file:///$project_home/1_evidence/'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/screencast "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/screenshot "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/screenshot-clip "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/window-screenshot "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/window-screenshot-clip "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/area-screenshot-clip "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/area-screenshot "''"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'gnome-screenshot -a'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'Print'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'custom-screenshot'"

    echoAction "Configuring screen recording"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/pipeline "'vp9enc min_quantizer=0 max_quantizer=5 cpu-used=3 deadline=1000000 threads=%T ! queue max-size-buffers=0 max-size-time=0 max-size-bytes=0 ! webmmux'"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/file-resolution-height "480"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/active-custom-gsp "true"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/file-resolution-width "640"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/quality-index "0"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/file-resolution-type "999"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/fps "3"
    dconf write /org/gnome/shell/extensions/EasyScreenCast/file-folder "'$project_home/1_evidence/'"

    echoAction "Performing last changes to shell"
    dconf write /org/gnome/shell/favorite-apps "['org.gnome.Nautilus.desktop', 'firefox-esr.desktop', 'terminator.desktop', 'sublime_text.desktop']"
    dconf write /org/gnome/desktop/background/picture-uri "'file:///usr/share/backgrounds/gnome/Dark_Ivy.jpg'"

    
  elif [ $WMver == "KDE" ]; then
    echoInfo "There are no customizations for KDE yet."
  
  else
    echoError "Window Manager could not be detected!"  
    
fi

echoAction "Changing hostname to $hostameVar"
sudo bash -c "sed -i 's/kali/$hostnameVar/g' /etc/hosts&&echo $hostnameVar > /etc/hostname"

echoInfo "All done - Now reboot for all changes to take effect..."
