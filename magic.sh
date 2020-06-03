#!/usr/bin/env bash

set -euo pipefail

if [[ $(which yq) == '' ]]; then
  echo "yq not found!"
  echo "Install yq with $> brew install yq"
  exit 1
fi

ORIGIN=$1
T_BRANCH=$2
#T_BRANCH=member-accounts-translations
#T_EN=account-core.en-US.yaml
#ORIGIN=origin
T_FILE_PATH=$3
T_EN=$(basename $T_FILE_PATH)
DIR="$( cd "$( dirname "$(realpath ${BASH_SOURCE[0]}) " )" >/dev/null 2>&1 && pwd )"
#T_DIR="$DIR/../sqs-i18n-translations/strings"
T_DIR=$(dirname $T_FILE_PATH)
ROOT_T_DIR=$(realpath --relative-to="$(git rev-parse --show-toplevel)" `pwd`/$T_DIR)
R_T_DIR=$(realpath --relative-to="$(pwd)" `pwd`/$T_DIR)


ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ -n $(git status -s) ]]; then
  echo "Error: git worktree dirty, please commit your changes then run again... exiting 1"
  exit 1;
fi

git fetch $ORIGIN $T_BRANCH:$T_BRANCH || (echo "
  - Encountered a problem syncing remote ${T_BRANCH} - resolve conflicts then run this tool on your branch again
  - To sync your local ${T_BRANCH} brute forcefully try $> git checkout ${T_BRANCH} && git reset --hard $ORIGIN/${T_BRANCH} && git checkout $ORIG_BRANCH
" && exit 1) 

npm run i18n:preTranslation || (echo "Warning! No new translation strings found! ... exiting 1" && exit 1)

files=$(git status --porcelain | sed s/^...// | grep sqs-i18n-translations)


if [[ -n $files ]]; then
  git show $ORIG_BRANCH:$ROOT_T_DIR/$T_EN | yq m -i $R_T_DIR/$T_EN - #yq merge translate branch in place
  awk 'NR==3{print "---"}1' $R_T_DIR/$T_EN > tmp_i18n && mv tmp_i18n $R_T_DIR/$T_EN
  git add $R_T_DIR/$T_EN
  git commit -m "Automated pre translations commit"
  cherry=$(git rev-parse HEAD)
  git checkout $T_BRANCH
  git show $cherry:$ROOT_T_DIR/$T_EN | yq m -i $R_T_DIR/$T_EN - #yq merge your in place
  awk 'NR==3{print "---"}1' $R_T_DIR/$T_EN > tmp_i18n && mv tmp_i18n $R_T_DIR/$T_EN
  git add $R_T_DIR/$T_EN
  git commit -m "Add english yaml updates for pre translations"
  echo #
  echo "${T_BRANCH} now contains the merged and updated strings"
  echo #
  echo "!!! Your new strings on $T_BRANCH still need pushed"
  echo #
  echo "> To push your changes for translation by idioma $> git push $ORIGIN $T_BRANCH:$T_BRANCH"
  echo #
  git checkout $ORIG_BRANCH
  else
    echo "Warning! No new translation strings found! ... exiting 1"
    exit 1
fi
