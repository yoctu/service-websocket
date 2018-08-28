#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="svxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -s      simulate
        -v      set -v
        -x      set -x
        -e      set -ve
        -h      Help

"

function _quit ()
{
    local retCode="$1" msg="${@:2}"

    echo -e "$msg"
    exit $retCode
}

function _notify()
{
    echo -e "\n\n\n\n\n################################## $* #####################################\n\n\n\n\n" >&2
}

while getopts "${OPTS}" arg; do
    case "${arg}" in
        s) _run="echo"                                                  ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        e) set -ve                                                      ;;
        h) _quit 0 "$HELP"                                              ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                           ;;
        *) _quit 1 "$USAGE"                                             ;;
    esac
done
shift $((OPTIND - 1))

# variables -> to source from config later
fileuuid="bck8:141360aa-4d5c-42c3-9c28-bd9d683b92db"
project="$(awk -F" " '/Source:/{print $2}' debian/control)"
ppaurl="https://ppa.yoctu.com"
filerurl="http://filer.test.flash-global.net"
term="automate@term.test.flash-global.net"


IFS=/ read refs heads branch <<<$CPHP_GIT_REF

trap '_quit 2 "An Error occured while running script"' ERR

_notify "Install dependencies"
sudo apt-get update >&/dev/null ; sudo apt-get install -y apt-transport-https devscripts debianutils jq gridsite-clients &>/dev/null 
wget -qO - $ppaurl/archive.key | sudo apt-key add -

curl -s -o /tmp/jq -O -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
chmod +x /tmp/jq
sudo mv /tmp/jq /usr/bin/jq

echo "deb $ppaurl/ all unstable" | sudo tee /etc/apt/sources.list 
sudo apt-get update &>/dev/null
cd /tmp

sudo apt-get install yoctu-client-scripts &>/dev/null

_notify "Finished installing dependecies"

_notify "Fetch changelog"
cd -

filer-client.sh -U $filerurl -X get -u $fileuuid

mv /tmp/$project-changelog debian/changelog

_notify "Fetched changelog"

_notify "Setup Github"
sudo -s curl -o /bin/git-to-deb -O -L $ppaurl/git-to-deb 
sudo chmod +x /bin/git-to-deb

git config --global user.email "git@yoctu.com"
git config --global user.name "git"
_notify "Setup done"

_notify "Build package"
git-to-deb -U build -u $branch >/dev/null 

filer-client.sh -U $filerurl -c MISCELLANEOUS -n "$project-changelog" -f debian/changelog -C "need=Changelog file for $project" -m "text/plain" -X update -u $fileuuid
_notify "Build done"

_notify "Rsync to ppa"
mv ../$project*.deb ../$project.deb
export LC_FLASH_PROJECT_ID="$project"
export LC_FLASH_BRANCH=$CPHP_GIT_REF && scp -P2222 -o StrictHostKeyChecking=no -i ~/.ssh/automate.key ../$project.deb $term:/tmp/${LC_FLASH_PROJECT_ID}.deb
_notify "Rsync done"

rm -rf debian

