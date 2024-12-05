# msf-installer
auto install metasploit-framework from github directly
Run with sudo or root

Tested on ubuntu and kali
kali: you have to remove metasploit package and ruby
please take snapshot of kali before running the script
```zsh
sudo apt remove metasploit-framework ruby
service postgresql start
```
db user msf pass msf

quick run
wget -qO msfinit.sh https://github.com/Audit00r/msf-installer/raw/refs/heads/main/msfinit.sh && bash msfinit.sh

ubuntu install
[![asciicast](https://asciinema.org/a/W3qhJJs8wj8FLZPPnQ7MrZVVS.svg)](https://asciinema.org/a/W3qhJJs8wj8FLZPPnQ7MrZVVS)
