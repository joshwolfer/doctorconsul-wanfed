#!/bin/bash

set -e

source ./scripts/functions.sh
# # ^^^ Variables and shared functions

help () {
  echo -e "Syntax: ./post-config.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -k3d      Include the default k3d configuration (doesn't accept additional kube-config.sh arguments)"
  echo ""
  exit 0
}

export ARG_HELP=false
export ARG_K3D=false

if [ $# -gt 0 ]; then
  for arg in "$@"; do
    case $arg in
      -help)
        ARG_HELP=true
        ;;
      -k3d)
        ARG_K3D=true
        ;;
      *)
        echo -e "${RED}Invalid Argument... ${NC}"
        echo ""
        help
        exit 1
        ;;
    esac
  done
fi

if $ARG_HELP; then
  help
fi

clear

mkdir -p ./tokens

# echo -e ""
# echo -e "${GRN}iptables: Blocking direct server to server access${NC}"

#   This is to insure that cluster peering is indeed working over mesh gateways.
#   Leaving them commented out so I make sure that other things aren't accidently blocked as we try new features.
#   Specificaly I want to make sure that I can send DNS requests to the servers.

# docker exec -i -t consul-server1-dc1 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.4 -j DROP"  # Block traffic from consul-server1-dc1 to consul-server1-dc2
# docker exec -i -t consul-server1-dc2 sh -c "/sbin/iptables -I OUTPUT -d 192.169.7.2 -j DROP"  # Block traffic from consul-server1-dc2 to consul-server-dc1

# echo "success"  # If the script didn't error out here, it worked.

# Wait for both DCs to electe a leader before starting resource provisioning
echo -e ""
echo -e "${GRN}Wait for both DCs to electer a leader before starting resource provisioning${NC}"

# Wait for Leaders to be elected (CONSUL_API_ADDR, Name of DC)
waitForConsulLeader "$DC1" "DC1"
waitForConsulLeader "$DC2" "DC2"

# ==========================================
#            Admin Partitions
# ==========================================

# To prevent possible timing issues in the setup of resources, all admin partitions for all Doctor Consul resources are immediately added first.
# The rest of the application resources, can be found in their respective scripts.

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Admin Partitions"
echo -e "==========================================${NC}"

# Create APs in DC1
echo -e ""
echo -e "${YELL}Evidently Partitions are completely incompatible with WAN Fed. So let's not actually use them... ${NC}"

# ==============================================================================================================================
#                                                 Baphomet Application
# ==============================================================================================================================

echo -e "${YELL}Running the Baphomet script:${NC} ./docker-configs/scripts/app-baphomet.sh"
./docker-configs/scripts/app-baphomet.sh


  # ------------------------------------------
  #           proxy-defaults
  # ------------------------------------------

# Managing race conditions....
# 1. When the _envoy side-car containers come up before ACLs have been set, they crash because the ACL doesn't exit.
# 2. So the containers are set to automatically restart on crash.
# 3. The ACL tokens are created in this script and when the Envoys restart, they'll pick up the ACL token.
# 4. proxy-defaults have to be written BEFORE the ACL tokens to make sure the prometheus listener is picked up on Envoy start.
#      Proxy-defaults won't restart Envoy proxies that are already running (/sigh)

# All this ^^^ to TLDR; Proxy-defaults MUST be set BEFORE Envoy side-car ACL tokens.

echo -e ""
echo -e "${GRN}proxy-defaults:${NC}"
echo -e ""

echo -e "${GRN}(DC1) default Partition:${NC} $(consul config write -http-addr="$DC1" ./docker-configs/configs/proxy-defaults/dc1-default-proxydefaults.hcl)"
echo -e "${GRN}(DC2) default Partition:${NC} $(consul config write -http-addr="$DC2" ./docker-configs/configs/proxy-defaults/dc2-default-proxydefaults.hcl)"

# ==========================================
#             ACLs / Auth N/Z
# ==========================================

echo -e ""
echo -e "${GRN}"
echo -e "=========================================="
echo -e "            ACLs / Auth N/Z"
echo -e "==========================================${NC}"

# ------------------------------------------
# Update the anonymous token so DNS isn't horked
# ------------------------------------------

# (1.17) Adds a DNS token so we only need to modify that instead. NMD.

echo -e ""
echo -e "${GRN}Add service:read to the anonymous token (enabling DNS Service Discovery):${NC}"

consul acl policy create -name dns-discovery -rules @./docker-configs/acl/dns-discovery.hcl -http-addr="$DC1"
consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-name dns-discovery -http-addr="$DC1"

# ------------------------------------------
#         Create ACL tokens in DC1
# ------------------------------------------

echo -e ""
echo -e "${GRN}ACL Token: 000000001111:${NC}"

consul acl token create \
    -node-identity=client-dc1-alpha:dc1 \
    -service-identity=joshs-obnoxiously-long-service-name-gonna-take-awhile-and-i-wonder-how-far-we-can-go-before-something-breaks-hrm:dc1 \
    -service-identity=josh:dc1 \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000001111" \
    -accessor="00000000-0000-0000-0000-000000001111" \
    -http-addr="$DC1"

# DC1 Policy + Role + Token

echo -e ""
echo -e "${GRN}ACL Policy+Role: DC1-read${NC}"

consul acl policy create -name dc1-read -rules @./docker-configs/acl/dc1-read.hcl -http-addr="$DC1"
consul acl role create -name dc1-read -policy-name dc1-read -http-addr="$DC1"

echo -e ""
echo -e "${GRN}ACL Token: 000000003333 (-role-name=dc1-read):${NC}"

consul acl token create \
    -role-name=dc1-read \
    -partition=default \
    -namespace=default \
    -secret="00000000-0000-0000-0000-000000003333" \
    -accessor="00000000-0000-0000-0000-000000003333" \
    -http-addr="$DC1"

# ------------------------------------------
#         Conul-Admins Role (God Mode)
# ------------------------------------------

echo -e "${GRN}"
echo -e "------------------------------------------"
echo -e "      Consul-Admins Role (God Mode)"
echo -e "------------------------------------------${NC}"
echo -e ""

consul acl role create -name consul-admins -policy-name global-management -http-addr="$DC1"

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#                                              WAN FED migration stuff
#  Disabling all this for now since we have to start with WAN fed. Will move it into a new migration script later.
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#  Moved to ./scripts/wanfed-migration.sh


# ==============================================================================================================================
#                                                 Unicorn Application
# ==============================================================================================================================

echo -e "${YELL}Running the Unicorn script:${NC} ./docker-configs/scripts/app-unicorn.sh"
./docker-configs/scripts/app-unicorn.sh

# ==============================================================================================================================
#                                                   Web Application
# ==============================================================================================================================

echo ""
echo -e "${YELL}Running the Web script:${NC} ./docker-configs/scripts/app-web.sh"
./docker-configs/scripts/app-web.sh

# ==========================================
#               k3d config
# ==========================================

if $ARG_K3D; then
  echo -e "${GRN} Launching k3d configuration script (kube-config.sh) ${NC}"
  ./kube-config.sh -k3d-full
  echo ""
fi

# ==============================================================================================================================
#                                                          Outputs
# ==============================================================================================================================

./docker-configs/scripts/vm-outputs.sh

# ------------------------------------------
# Test STUFF
# ------------------------------------------

# curl -sL --header "X-Consul-Token: root" "localhost:8500/v1/discovery-chain/unicorn-backend?ns=backend&partition=unicorn" | jq
# curl -sL --header "X-Consul-Token: root" "localhost:8500/v1/discovery-chain/unicorn-backend?ns=frontend&partition=unicorn" | jq

# curl -sL --header "X-Consul-Token: root" "$DC1/v1/discovery-chain/unicorn-backend?ns=backend&partition=unicorn" | jq
# curl -sL --header "X-Consul-Token: root" "$DC2/v1/discovery-chain/unicorn-backend?ns=backend&partition=unicorn" | jq


# You can specify config entries in the agent config. This might simplify some of the config.

# config_entries {
#    bootstrap {
#       kind = "proxy-defaults"
#       name = "global"
#       config {
#          envoy_dogstatsd_url = "udp://127.0.0.1:9125"
#       }
#    }
#    bootstrap {
#       kind = "service-defaults"
#       name = "foo"
#       protocol = "tcp"
#    }
# }



