#!/bin/bash

# Metasploit framework install and setup
# 1) install dependencies
# 2) install ruby 
# 3) configure postgre db form MSF
# 4) install MSF from Github 
# 5) setup symlinks and db config
# This scripted tested on ubuntu 22.04 and 24.04
# in Kali you need to uninstall msf from apt remove
# by audit00r
# https://github.com/Audit00r/msf-installer
# @syfi


GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m" # No color

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}This script must be run as root. Please execute it with 'sudo' or as the root user.${NC}"
  exit 1
fi

# Helper functions
function print_phase() {
  echo -e "${CYAN}\n### $1 ###${NC}"
}

function handle_error() {
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error occurred in phase: $1. Continuing to the next phase...${NC}"
  fi
}

# Record the start time
start_time=$(date +%s)

# Phase 1: Installing dependencies
print_phase "Phase 1: Installing dependencies"
dependencies=(
  build-essential libreadline-dev libssl-dev libpq5 libpq-dev libreadline8
  libsqlite3-dev libpcap-dev git-core autoconf postgresql curl zlib1g-dev
  libxml2-dev libxslt1-dev libyaml-dev libz-dev gawk bison libffi-dev
  libgdbm-dev libncurses5-dev libtool sqlite3 libgmp-dev gnupg2 dirmngr
)

for package in "${dependencies[@]}"; do
  echo -e "${GREEN}Installing $package...${NC}"
  apt-get install -y $package &>/dev/null
  handle_error "Installing $package"
done

# Phase 2: Setting up rbenv
print_phase "Phase 2: Setting up rbenv"
if [ -d "$HOME/.rbenv" ]; then
  echo -e "${RED}rbenv already exists. Skipping...${NC}"
else
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
  echo -e "${GREEN}rbenv setup completed.${NC}"
fi

# Phase 3: Installing ruby-build and rbenv-sudo
print_phase "Phase 3: Installing ruby-build and rbenv-sudo"
if [ -d "$HOME/.rbenv/plugins/ruby-build" ]; then
  echo -e "${RED}ruby-build already exists. Skipping...${NC}"
else
  git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
fi
if [ -d "$HOME/.rbenv/plugins/rbenv-sudo" ]; then
  echo -e "${RED}rbenv-sudo already exists. Skipping...${NC}"
else
  git clone https://github.com/dcarley/rbenv-sudo.git ~/.rbenv/plugins/rbenv-sudo
fi
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
echo -e "${GREEN}ruby-build and rbenv-sudo setup completed.${NC}"

# Phase 4: Installing Ruby
print_phase "Phase 4: Installing Ruby"
RUBYVERSION=$(wget https://raw.githubusercontent.com/rapid7/metasploit-framework/master/.ruby-version -q -O -)

echo -e "${GREEN}Installing Ruby $RUBYVERSION... This may take a while.${NC}"

apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev &>/dev/null

# Run Ruby installation
(rbenv install $RUBYVERSION &>/tmp/rbenv_install.log) &
pid=$!

while kill -0 $pid 2>/dev/null; do
  echo -n "."
  sleep 5
done

if rbenv versions | grep -q "$RUBYVERSION"; then
  rbenv global $RUBYVERSION
  echo -e "\n${GREEN}Ruby $RUBYVERSION installation completed successfully.${NC}"
else
  echo -e "\n${RED}Ruby installation failed. Check /tmp/rbenv_install.log for details.${NC}"
  exit 1
fi
# Phase 5: Setting up PostgreSQL database
print_phase "Phase 5: Setting up PostgreSQL database"
cat <<EOF > /tmp/setup_postgres.sh
#!/bin/bash
cd ~
createuser msf -P -S -R -D <<PASS
msf
msf
PASS
createdb -O msf msf
EOF

chmod +x /tmp/setup_postgres.sh
su - postgres -c "bash /tmp/setup_postgres.sh"
handle_error "Setting up PostgreSQL database"
rm -f /tmp/setup_postgres.sh
echo -e "${GREEN}PostgreSQL database setup completed successfully.${NC}"

# Phase 6: Cloning Metasploit Framework
print_phase "Phase 6: Cloning Metasploit Framework"
if [ -d "/opt/metasploit-framework" ]; then
  echo -e "${RED}Metasploit Framework already exists. Skipping...${NC}"
else
  git clone https://github.com/rapid7/metasploit-framework.git /opt/metasploit-framework
  handle_error "Cloning Metasploit Framework"
fi
echo -e "${GREEN}Metasploit Framework setup completed.${NC}"

# Phase 7: Installing MSF gems
print_phase "Phase 7: Installing gems"
cd /opt/metasploit-framework || exit
gem install bundler && bundle install
handle_error "Installing gems"
echo -e "${GREEN}Gem installation completed.${NC}"

# Phase 8: Creating symbolic links
print_phase "Phase 8: Creating symbolic links for Metasploit commands"
for MSF in $(ls msf*); do
  if [ -L "/usr/local/bin/$MSF" ]; then
    echo -e "${RED}Symbolic link for $MSF already exists. Skipping...${NC}"
  else
    ln -s /opt/metasploit-framework/$MSF /usr/local/bin/$MSF
  fi
done
echo -e "${GREEN}Symbolic links for Metasploit created.${NC}"

# Phase 9: Database configuration
print_phase "Phase 9: Configuring database"
cat <<EOF > /opt/metasploit-framework/config/database.yml
production:
  adapter: postgresql
  database: msf
  username: msf
  password: msf
  host: 127.0.0.1
  port: 5432
  pool: 75
  timeout: 5
EOF
echo -e "${GREEN}Database configuration completed successfully.${NC}"

# Phase 10: Setting environment variables
print_phase "Phase 10: Setting environment variables"
echo "export MSF_DATABASE_CONFIG=/opt/metasploit-framework/config/database.yml" >> /etc/profile
source /etc/profile
echo -e "${GREEN}Environment variables for Metasploit configured.${NC}"

end_time=$(date +%s)
time_taken=$((end_time - start_time))
echo -e "${CYAN}\n### Time Taken: $time_taken seconds ###${NC}"
