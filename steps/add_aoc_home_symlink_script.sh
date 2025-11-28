#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

if [[ $MAGAOX_ROLE != RTC && $MAGAOX_ROLE != ICC ]]; then
    exit_with_error "Ensure this role $MAGAOX_ROLE has a route to AOC over the private LAN before enabling"
fi

if [[ $MAGAOX_ROLE != AOC ]]; then
    sudo tee /etc/profile.d/make_aoc_home_symlink.sh <<'HERE'
#!/usr/bin/env bash
if [[ $USER != xsup && $USER != xdev && ! -e /home/$USER/aoc ]]; then
    echo 'Making AOC home directory accessible over the network at ~/aoc/...'
    ln -sv /srv/aoc/home/$USER/ /home/$USER/aoc || echo "Couldn't make symlink at /home/$USER/aoc"
fi
HERE
    sudo chmod +x /etc/profile.d/make_aoc_home_symlink.sh
    log_info 'Added shell profile snippet to symlink ~/aoc to /srv/aoc/home/$USER'
fi
