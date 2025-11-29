#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

if [[ $MAGAOX_ROLE != RTC && $MAGAOX_ROLE != ICC ]]; then
    exit_with_error "Ensure this role $MAGAOX_ROLE has a route to AOC over the private LAN before enabling"
fi

if [[ $MAGAOX_ROLE != AOC ]]; then
    sudo tee /etc/profile.d/init_users_data_dir.sh <<'HERE'
#!/usr/bin/env bash
if [[ ! -e /home/$USER/data ]]; then
    echo 'Making AOC home directory accessible over the network at ~/data/...'
    ln -sv /srv/aoc/home/$USER/data/ /home/$USER/data || echo "Couldn't make symlink at /home/$USER/data"
fi
HERE
    sudo chmod +x /etc/profile.d/init_users_data_dir.sh
    log_info 'Added shell profile snippet to symlink ~/data to /srv/aoc/home/$USER/data'
else
        sudo tee /etc/profile.d/init_users_data_dir.sh <<'HERE'
#!/usr/bin/env bash
if [[ ! -e /home/$USER/data ]]; then
    echo 'Making ~/data/ dir for sharing between instruments...'
    mkdir -p /home/$USER/data || echo "Couldn't make a data dir in home"
fi
HERE
    sudo chmod +x /etc/profile.d/init_users_data_dir.sh
    log_info 'Added shell profile snippet to make ~/data on first login'
fi
