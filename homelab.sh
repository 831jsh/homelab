#!/bin/sh

# variables
program_name=$(basename $0)
ansible=$(which ansible-playbook)
pwd=$(pwd)
ansible_base="${pwd}/ansible"
inventory_file="${ansible_base}/inventory/all.yaml"

# functions
sub_help(){
  echo "Usage: ${program_name} <subcommand> [options]\n"
  echo "Subcommands:"
  echo "    install         Initialize the cluster by ensuring an expected state"
  echo "    upgrade         Perform an upgrade on the cluster"
  echo "    uninstall       Uninstalls everything that was previously setup"
  echo "    kubeconfig      Retrieves the admin kube config from a master"
  echo "    reboot [hosts]  Reboots the host(s); 'all' is the default"
  echo ""
  echo "For help with each subcommand run:"
  echo "${program_name} <subcommand> -h|--help"
  echo ""
}

sub_upgrade(){
  sub_command=$1

  case ${sub_command} in
    "" | "-h" | "--help")
      sub_upgrade_help
      ;;
    *)
      shift
      sub_upgrade_${sub_command} $@
      if [ $? = 127 ]; then
        show_error "upgrade ${sub_command}"
      fi
      ;;
  esac
}

sub_upgrade_help(){
  echo "Usage: ${program_name} upgrade <subcommand> [options]\n"
  echo "Subcommands:"
  echo "    os   Perform a host-level package upgrade"
  echo "    k8s  Perform an upgrade on Kubernetes-related packages & components"
  echo ""
  echo "For help with each subcommand run:"
  echo "${program_name} upgrade <subcommand> -h|--help"
}

sub_upgrade_os(){
  ${ansible} -i ${inventory_file} ${ansible_base}/upgrade-os.yaml --ask-become-pass
}

sub_upgrade_k8s(){
  echo "todo: Performing upgrade k8s"
}

sub_install(){
  ${ansible} -i ${inventory_file} ${ansible_base}/install.yaml --ask-become-pass
}

sub_uninstall(){
  ${ansible} -i ${inventory_file} ${ansible_base}/uninstall.yaml --ask-become-pass
}

sub_kubeconfig(){
  ${ansible} -i ${inventory_file} ${ansible_base}/get-admin-kube-config.yaml --ask-become-pass
}

sub_reboot() {
  hosts=${1}

  if [ "$hosts" = "" ]; then
    hosts="all"
  fi

  ${ansible} -i ${inventory_file} ${ansible_base}/reboot.yaml --ask-become-pass --extra-vars="reboot_hosts=${hosts}"
}

show_error(){
  command=$1

  echo "Error: '${command}' is not a known subcommand." >&2
  echo "---> Run '${program_name} ${command} --help' for a list of known subcommands." >&2
  exit 1
}

# main point of entry
sub_command=$1
case ${sub_command} in
  "" | "-h" | "--help")
    sub_help
    ;;
  *)
    shift
    sub_${sub_command} $@
    if [ $? = 127 ]; then
      show_error ${sub_command}
    fi
    ;;
esac
