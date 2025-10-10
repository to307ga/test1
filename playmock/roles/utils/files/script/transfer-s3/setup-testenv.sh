#!/usr/bin/env bash
# Setup the test environment.

# Fail on unset variables and command errors
# set -ue -o pipefail
set -u -o pipefail # errexit disabled
# Prevent commands misbehaving due to locale differences
export LC_ALL=C

# --update option
UPDATE=0

# process options.
if [[ ${1:-} == "--update" ]]; then
    UPDATE=1
fi

#
# Bats installation. (Bats is Bash Automated Testing System)
#
if [ -d test/bats ]; then
    if [[ $UPDATE == 1 ]]; then
        echo "Updating bats."
        (
            cd test/bats
            git pull
        )
    else
        echo "bats already installed."
    fi
else
    git clone https://github.com/bats-core/bats-core.git ./test/bats
fi

# and Bats test helpers below.

#
# Bats support installation.
#
if [ -d test/test_helper/bats-support ]; then
    if [[ $UPDATE == 1 ]]; then
        echo "Updating bats-support."
        (
            cd test/test_helper/bats-support
            git pull
        )
    else
        echo "bats-support already installed."
    fi
else
    git clone https://github.com/bats-core/bats-support.git ./test/test_helper/bats-support
fi

#
# Bats assert installation.
#
if [ -d test/test_helper/bats-assert ]; then
    if [[ $UPDATE == 1 ]]; then
        echo "Updating bats-assert."
        (
            cd test/test_helper/bats-assert
            git pull
        )
    else
        echo "bats-assert already installed."
    fi
else
    git clone https://github.com/bats-core/bats-assert.git ./test/test_helper/bats-assert
fi

#
# Bats file installation.
#
if [ -d test/test_helper/bats-file ]; then
    if [[ $UPDATE == 1 ]]; then
        echo "Updating bats-file."
        (
            cd test/test_helper/bats-file
            git pull
        )
    else
        echo "bats-file already installed."
    fi
else
    git clone https://github.com/bats-core/bats-file.git ./test/test_helper/bats-file
fi


#
# Append bats alias to ~/.bash_aliases
#
if alias bats >/dev/null 2>&1; then
    echo "Alias already appended."
else
    {
        echo ""
        echo "# Bats - Bash Automated Testing System"
        echo "alias bats='[ -f bats ] && bash bats || bash test/bats/bin/bats'"
    } >>~/.bashrc
    echo "please run following command: source ~/.bashrc"
fi

#EOS
