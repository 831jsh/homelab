#!/bin/sh

program_name=$(basename $0)
ansible=$(which ansible-playbook)
pwd=$(pwd)
ansible_base="${pwd}/ansible"
inventory_file="${ansible_base}/inventory/hosts"

sub_help(){
    echo "Usage: ${program_name} <subcommand> [options]\n"
    echo "Subcommands:"
    echo "    upgrade   Perform an upgrade on the cluster"
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
    echo "Performing upgrade k8s"
}

show_error(){
    command=$1

    echo "Error: '${command}' is not a known subcommand." >&2
    echo "---> Run '${program_name} ${command} --help' for a list of known subcommands." >&2
    exit 1
}

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
