#!/bin/bash

function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 1 ;;  
            [Nn]*) return 0 ;;
        esac
    done
}

fontdir=~/.local/share/fonts/papertty-init
bindir=~/.local/bin/papertty-init
installdir=~/.local/share/papertty-init_venv
autodir=~/.config/autostart/

#Check if the user is root
if [ "$EUID" -eq 0 ]; then
  echo "Do not run this script as root."
  echo "This script should be run as an ordinary user who has sudo privileges."
  echo "eg. The default 'pi' user."
  exit
fi


echo ""
echo "*********************"
echo "* PaperTTY GUI Init *"
echo "*********************"
echo ""
echo "This script will set up a raspberry pi to automatically run papertty on boot."
echo "It will automatically log you in as your current user ($USER) and provide you with a desktop environment."
echo "It will then either switch you to a terminal interface, or run tmux on your desktop and send its input to tty1."
echo ""
echo "Note that this script should ONLY be run from a raspberry pi."
echo "It assumes that you are using a fresh installation of Raspberry Pi OS."
echo "It also assumes that you are using the full version of Raspberry Pi OS with a desktop installed, rather than the Lite version."
echo "If any of those assumptions are wrong, then this script will probably not work."
echo ""
echo "Also note that this script has only been tested on the latest version of Raspberry Pi OS (based on Debian 12 Bookworm)."
echo "Older versions of Raspberry Pi OS should theoretically still work, but have not been tested."
echo ""
yes_or_no "Do you want to continue?"
shouldContinue=$?

if [ $shouldContinue -eq 0 ]; then
  echo "Aborting installation"
  exit;
fi

echo ""
echo ""
echo "You will now be asked a few questions about your desired setup."

#First, let's try to determine which raspberry pi model is being used.
#The pi model should be a string like "Raspberry Pi 4 Model B Rev 1.5"
#The part we want is the first number (4, in the example above).
#"cut" starts at 1, not 0. So we want char 14.
pimodel=$(cat /proc/device-tree/model | cut -c14)

#If the number is 5 or higher, set a flag to let the rest of the program know
#that we're targeting a new model.
#This is important because of changes to the GPIO pin memory mapping as of the rpi5.
if [ $pimodel -gt 4 ]; then
  pi5=1
else
  pi5=0
fi

echo ""
echo ""
echo ""
echo "#1 PaperTTY version"
echo "There are two places this script can download PaperTTY from."
echo "The first is the official git repository: https://github.com/joukos/PaperTTY"
echo "The second is my fork of PaperTTY: https://github.com/ton-an/PaperTTY"
echo ""
echo "The two repositories are usually identical."
echo "However, new features I've added land in the fork first, then get submitted as pull requests to the official repository."
echo "So you can think of the forked repository as kind of like a beta version."
echo ""
yes_or_no "Use forked repository?"
usefork=$?

echo ""
echo ""
echo ""
echo "#2 GPIO library"
echo "Which GPIO library do you want to use?"
echo "There are 2 options: gpiozero and RPi.GPIO"
echo ""
echo "RPi.GPIO has been used with PaperTTY for longer, and it is well-tested."
echo "However, it is no longer updated, and it does not work with the raspberry pi 5 or newer devices."
echo ""
echo "gpiozero hasn't been used with PaperTTY for as long, or as intensively."
echo "But it is regularly updated and it is supported by newer devices."
echo ""
echo "There should not be any major performance differences between the two."
echo ""
yes_or_no "Use gpiozero?"
gpiozero=$?

echo ""
echo ""
echo ""
echo "#3 Desktop mode"
echo "How do you want your raspberry pi to behave when a HDMI monitor is plugged in?"
echo ""
echo "Option 1 is to show tty1 (a text-only interface) by default."
echo "Everything you type will show on both the monitor and the e-ink panel."
echo "You would then press Ctrl + Alt + F7 when you need to access your desktop."
echo "Or Ctrl + Alt + F1 to get back to tty1 and resume typing on the e-ink panel."
echo ""
echo "Option 2 is to send text to the e-ink panel through another application (tmux)."
echo "This means you'll have a desktop running by default when you plug in your HDMI."
echo "However, this also means tmux needs to remain in focus for text to transfer."
echo "So popup windows and such from other applications can prevent you from typing."
echo "It's also possible to accidentally use desktop shortcuts or exit tmux."
echo ""
read -p "Press Enter to continue"
echo ""
echo ""
echo ""
echo "Option 2 is only safe if you will always be connected to a HDMI monitor."
echo "It is not suitable for projects which only utilize the e-ink panel."
echo "It also requires you to perform some manual changes to the tmux script"
echo "to make sure the panel size and the tmux size are both the same."
echo "It will require trial and error from you, and there are several things"
echo "which can go wrong."
echo ""
echo "Unless you're planning to use this primarily as a desktop PC over HDMI, with"
echo "the e-ink panel being a secondary display which you don't use as often, it's"
echo "highly recommended that you go with option 1."
echo ""
echo "Note that it IS possible to change your mind later on, after installation."
echo "You can do this by going into the Startup Applications menu and enabling either"
echo "PaperttyInitStartTmux (option 2) or PaperttyInitSwitchTty (option 1)."
echo "You should only ever have one or the other turned on. Not both."
echo ""
yes_or_no "Go with Option 1?"
usetty=$?

echo ""
echo ""
echo ""
echo "#4 Panel driver"
echo "Which waveshare panel are you going to be using?"
echo "If you are using a HD panel, then you probably want the IT8951 driver."
echo "All of the supported models and drivers will be listed in the next step."
read -p "Press Enter to continue"

echo "Supported panels/drivers are:"

panels=(
    EPD1in54
    EPD1in54b
    EPD1in54c
    EPD2in7
    EPD2in7b
    EPD2in9
    EPD2in9b
    EPD2in13
    EPD2in13b
    EPD2in13d
    EPD2in13v2
    EPD3in7
    EPD4in2
    EPD4in2b
    EPD5in65f
    EPD5in83
    EPD5in83b
    EPD7in3f
    EPD7in5
    EPD7in5b_V2
    EPD7in5v2
    EPD7in5b
    IT8951
)
while true; do
    for i in "${panels[@]}"; do
        echo "$i"
    done
    read -p "Enter one of the choices above: " panel
    found=0
    for i in "${panels[@]}"; do
        if [ "$panel" == "$i" ]; then
            found=1
            break
        fi
    done
    if [ $found -eq 1 ]; then
        break
    else
        echo "No match found."
    fi
done

echo ""
echo ""
echo "Your settings are as follows:"
if [ $usefork -eq 1 ]; then
    echo "PaperTTY version: forked"
    gitrepo="ton-an"
else
    echo "PaperTTY version: official"
    gitrepo="joukos"
fi
if [ $gpiozero -eq 1 ]; then
    echo "Library: gpiozero"
else
    echo "Library: RPi.GPIO"
fi
if [ $usetty -eq 1 ]; then
    echo "Desktop mode: tty"
else
    echo "Desktop mode: tmux"
fi
echo "Panel/driver: $panel"
echo ""
echo "Is this all correct?"
echo "Installation will start immediately if you say yes."
echo "It will also take a while to install, especially on a slow internet connection."
yes_or_no "Proceed?"
allCorrect=$?
if [ $allCorrect -eq 0 ]; then
  echo "Aborting installation"
  exit
fi



echo ""
echo ""
echo ""
echo "Creating setup directories"
mkdir -p $fontdir $bindir $autodir

echo "Updating apt cache"
sudo apt update

echo "Installing dependencies"
sudo apt install -y python3-venv python3-pip libopenjp2-7 libtiff5-dev libjpeg-dev libfreetype-dev tmux git wget unzip

echo "Creating python virtual environment - This might take a minute"
python3 -m venv $installdir

echo "Installing papertty"
$installdir/bin/pip3 install papertty

if [ $gpiozero -eq 1 ]; then
    echo "Installing gpiozero"
    $installdir/bin/pip3 install gpiozero
fi

# For running PaperTTY over USB. eg. Via the IT8951 microUSB port
echo "Installing pyusb"
$installdir/bin/pip3 install pyusb


#Download a newer version of papertty from git, since the version
#in pip is probably old.
#Note that python* is used since the exact version of python3 might change

echo "Downloading a newer version of papertty"
cd $installdir/lib/python*/site-packages/
rm -rf papertty
git clone https://github.com/$gitrepo/PaperTTY tmp_papertty
mv tmp_papertty/papertty papertty
rm -rf tmp_papertty


#Download and install the Ubuntu fonts.
#There are other options available which might be a good choice.
#Anything Mono should be fine.

echo "Downloading and installing fonts"
cd /tmp/
wget https://assets.ubuntu.com/v1/0cef8205-ubuntu-font-family-0.83.zip
unzip 0cef8205-ubuntu-font-family-0.83.zip
mv ubuntu-font-family-0.83/*.ttf $fontdir
rm 0cef8205-ubuntu-font-family-0.83.zip
rm -rf ubuntu-font-family-0.83


echo "Creating init scripts"

#Creating script for running tmux on tty1 and attaching to it from the default tty.
#This is used if someone wants to keep the GUI active.
#For example, so they can have a proper desktop open on an LCD monitor while
#also running papertty on the waveshare panel.
#Or, more likely, so they can plug in a HDMI cable at any time to reach the GUI,
#if they need to.

echo "Creating tmux startup script: $bindir/starttmux.sh"

cat <<EOF > $bindir/starttmux.sh
#!/bin/bash
sudo openvt -fc 1 -- sudo -u $USER tmux new -s main
sleep 2s
#tmux send-keys -t "main" "insert command here" ENTER
tmux set -t "main" status off
tmux attach -t "main"
EOF
chmod +x $bindir/starttmux.sh


#Startup script for papertty itself.
#Currently uses some sane(?) default values and leave it up to the user to
#modify the values later.
#Adding some choices to the installer might be nice, but realistically the
#user won't know what the appropriate values are until they try actually running
#papertty and seeing what works for their panel.

echo "Creating papertty startup script: $bindir/startpapertty.sh"

cat <<EOF > $bindir/startpapertty.sh
#!/bin/bash
sudo $installdir/bin/papertty --driver $panel terminal --autofit --portrait --size 30 --font $fontdir/UbuntuMono-R.ttf
EOF
chmod +x $bindir/startpapertty.sh


#Script for disabling power management in various ways.
#It's likely overkill. Some of these are probably unnecessary.
#The sleep statements may not be necessary either.

echo "Creating power management script: $bindir/disablepm.sh"

cat <<EOF > $bindir/disablepm.sh
#!/bin/bash
sleep 1s
xset -dpms
sleep 1s
xset s off
sleep 1s
xset s noblank
sleep 1s
xfce4-power-manager -q
EOF
chmod +x $bindir/disablepm.sh


#Install xfce desktop
echo "Installing XFCE"
sudo tasksel install xfce-desktop

#Create a backup of the lightdm config
echo "Backing up lightdm config to: /etc/lightdm/lightdm.conf.bak"
sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak

#Comment out the existing autologin session
#Also add a new line to set the login session to xfce
echo "Enabling autologin for XFCE"
sudo sed -i 's/^autologin-session/autologin-session=xfce\n#autologin-session/g' /etc/lightdm/lightdm.conf

echo "Enabling SPI"
sudo raspi-config nonint do_spi 0


#Now let's go into the autostart directory and add some startup programs
cd $autodir


#First, let's figure out if we're going to run tmux or tty.
#We're going to add both .desktop files to the autostart directory,
#but only turn one of them on.
#Hidden=true/false determines whether it's turned on or not.

if [ $usetty -eq 1 ]; then
    hidetmux=true
    hidetty=false
else
    hidetmux=false
    hidetty=true
fi

echo "Creating autostart applications"

echo "Creating $autodir/PaperttyInitStartTmux.desktop"
cat <<EOF > PaperttyInitStartTmux.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=PaperttyInitStartTmux
Comment=Starts a tmux session on login
Exec=xfce4-terminal --maximize -e $bindir/starttmux.sh
RunHook=0
StartupNotify=false
Terminal=false
Hidden=$hidetmux
EOF

echo "Creating $autodir/PaperttyInitSwitchTty.desktop"
cat <<EOF > PaperttyInitSwitchTty.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=PaperttyInitSwitchTty
Comment=Switch to tty1 on login
Exec=sudo chvt 1
RunHook=0
StartupNotify=false
Terminal=false
Hidden=$hidetty
EOF

echo "Creating $autodir/PaperttyInitStartPaperTTY.desktop"
cat <<EOF > PaperttyInitStartPaperTTY.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=PaperttyInitStartPaperTTY
Comment=Starts papertty on login
Exec=$bindir/startpapertty.sh
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF

echo "Creating $autodir/PaperttyInitDisablePowerManager.desktop"
cat <<EOF > PaperttyInitDisablePowerManager.desktop
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=PaperttyInitDisablePowerManager
Comment=Disables power manager to keep screen awake
Exec=$bindir/disablepm.sh
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF

#Disable light-locker so the session doesn't lock
#This isn't a good solution and will probably be overwritten by OS updates
echo "Disabling screen locker"
echo "Hidden=true" | sudo tee -a /etc/xdg/autostart/light-locker.desktop

#Also disable screen blanking so the display doesn't go to sleep
#This is probably overkill
echo "Disabling screen blanking"
sudo raspi-config nonint do_blanking 1


echo ""
echo ""
echo ""
echo "Installation has finished."
echo "You will need to reboot before the changes take effect."
echo ""
echo "Note that you may still need to edit the papertty startup script to suit your preferences."
echo "eg. To change the font, font size, screen orientation, etc."
echo "The startup script can be found at: $bindir/startpapertty.sh"
