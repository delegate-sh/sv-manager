#!/bin/bash
#set -x -e

echo "###################### WARNING!!! ######################"
echo "###   This script will install and/or reconfigure    ###"
echo "### telegraf and point it to solana.thevalidators.io ###"
echo "########################################################"

install_monitoring () {

  echo "### Which cluster you wnat to monitor? ###"
  select cluster in "mainnet-beta" "testnet"; do
      case $cluster in
          mainnet-beta ) inventory="mainnet.yaml"; break;;
          testnet ) inventory="testnet.yaml"; break;;
      esac
  done


  echo "### Please type your validator name: "
  read VALIDATOR_NAME
  echo "### Please Enter the vote account pubkey: "
  read VOTE_ACCOUNT_PUBKEY

  read -e -p "### Please tell which user is running validator: " SOLANA_USER
  cd
  rm -rf sv_manager/

  if [[ $(which apt | wc -l) -gt 0 ]]
  then
  pkg_manager=apt
  elif [[ $(which yum | wc -l) -gt 0 ]]
  then
  pkg_manager=yum
  fi

  echo "### Update packages... ###"
  $pkg_manager update
  echo "### Install ansible, curl, unzip... ###"
  $pkg_manager install ansible curl unzip --yes
  
  # fix for eventually hanging of pip
  export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring

  ansible-galaxy collection install ansible.posix
  ansible-galaxy collection install community.general

  echo "### Download Solana validator manager"
  cmd="https://github.com/delegate-sh/sv-manager/archive/refs/tags/$1.zip"
  echo "starting $cmd"
  curl -fsSL "$cmd" --output sv_manager.zip
  echo "### Unpack Solana validator manager ###"
  unzip ./sv_manager.zip -d .

  mv sv-manager* sv_manager
  rm ./sv_manager.zip
  cd ./sv_manager || exit
  cp -r ./inventory_example ./inventory

  #echo $(pwd)
  ansible-playbook --connection=local --inventory ./inventory/$inventory --limit localhost  playbooks/pb_config.yaml --extra-vars "{ \
  'solana_user': '$SOLANA_USER', \
  'validator_name':'$VALIDATOR_NAME', \
  'vote_account_pubkey': '$VOTE_ACCOUNT_PUBKEY' \
  }"

  ansible-playbook --connection=local --inventory ./inventory/$inventory --limit localhost  playbooks/pb_install_monitoring.yaml --extra-vars "@/etc/sv_manager/sv_manager.conf"

  echo "### Cleanup install folder ###"
  cd ..
  rm -r ./sv_manager
  echo "### Cleanup install folder done ###"
  echo "### Check your dashboard: https://solana.thevalidators.io/d/e-8yEOXMwerfwe/solana-monitoring?&var-server="$VALIDATOR_NAME

  echo Do you want to UNinstall ansible?
  select yn in "Yes" "No"; do
      case $yn in
          Yes ) $pkg_manager remove ansible --yes; break;;
          No ) echo "### Okay, ansible is still installed on this system.  ###"; break;;
      esac
  done

}

echo Do you want to install monitoring?
select yn in "Yes" "No"; do
    case $yn in
        Yes ) install_monitoring "${1:-v1.0.2}"; break;;
        No ) echo "### Aborting install. No changes are made on the system."; exit;;
    esac
done
