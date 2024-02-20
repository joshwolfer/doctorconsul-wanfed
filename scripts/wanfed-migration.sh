#!/bin/bash

set -e

# source ./scripts/functions.sh
source ./functions.sh
# # ^^^ Variables and shared functions

# ==========================================
#             Cluster Peering
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "            Cluster Peering"
echo -e "==========================================${NC}"

# Set peering to use Mesh Gateways for peering control plane traffic. This must be set BEFORE peering tokens are created.
# Because of the potential timing issues. I have not peered partitions for specific apps (like unicorn / web) in their respective scripts.
# This seemed like a better option.

echo -e ""
echo -e "${GRN}Set peering to use Mesh Gateways for peering control plane traffic.${NC}"

consul config write -http-addr="$DC1" ./docker-configs/configs/mgw/dc1-mgw.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/mgw/dc2-mgw.hcl

# Peer DC1/default <- DC2/default

echo -e ""
echo -e "${GRN}Peer DC1/default <- DC2/default${NC}"

consul peering generate-token -name dc2-default -http-addr="$DC1" > tokens/peering-dc1_default-dc2-default.token
consul peering establish -name dc1-default -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-dc2-default.token)

# Peer DC1/default <- DC2/heimdall

echo -e ""
echo -e "${GRN}Peer DC1/default <- DC2/heimdall${NC}"

consul peering generate-token -name dc2-heimdall -partition="default" -http-addr="$DC1" > tokens/peering-dc1_default-dc2-heimdall.token
consul peering establish -name dc1-default -partition="heimdall" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_default-dc2-heimdall.token)

# Peer DC1/default -> DC2/chunky

echo -e ""
echo -e "${GRN}Peer DC1/default -> DC2/chunky${NC}"

consul peering generate-token -name dc1-default -partition="chunky" -http-addr="$DC2" > tokens/peering-dc2_chunky-dc1-default.token
consul peering establish -name dc2-chunky -partition="default" -http-addr="$DC1" -peering-token $(cat tokens/peering-dc2_chunky-dc1-default.token)

# Peer DC1/unicorn <- DC2/unicorn

echo -e ""
echo -e "${GRN}Peer DC1/unicorn <- DC2/unicorn${NC}"

consul peering generate-token -name dc2-unicorn -partition="unicorn" -http-addr="$DC1" > tokens/peering-dc1_unicorn-dc2-unicorn.token
consul peering establish -name dc1-unicorn -partition="unicorn" -http-addr="$DC2" -peering-token $(cat tokens/peering-dc1_unicorn-dc2-unicorn.token)


  # ------------------------------------------
  # Export services across Peers
  # ------------------------------------------

echo -e ""
echo -e "${GRN}exported-services:${NC}"

# Exported services are scoped to the PARTITION. Only 1 monolithic config can exist per partition.
# Multiple written configs to the same partition will stomp each other. Good times!
# This is addressed in the Consul V2 API

# Export the DC1/Donkey/default/Donkey service to DC1/default/default
consul config write -http-addr="$DC1" ./docker-configs/configs/exported-services/exported-services-donkey.hcl


# Export the default partition services to various peers
consul config write -http-addr="$DC1" ./docker-configs/configs/exported-services/exported-services-dc1-default.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/exported-services/exported-services-dc2-default.hcl


# ------------------------------------------
# Export services across Peers (Unicorn)
# ------------------------------------------

echo -e ""
echo -e "${GRN}exported-services:${NC}"

# Export the DC1/unicorn/backend/unicorn-backend service to DC1/default
# DC1/unicorn (exports unicorn cross-partition to default)
consul config write -http-addr="$DC1" ./docker-configs/configs/exported-services/exported-services-dc1-unicorn.hcl

# Export the DC2/unicorn/backend/unicorn-backend service to DC1/default
consul config write -http-addr="$DC2" ./docker-configs/configs/exported-services/exported-services-dc2-unicorn_backend.hcl


# ------------------------------------------
# Export services across Peers (web)
# ------------------------------------------

echo -e ""
echo -e "${GRN}exported-services:${NC}"

# DC2/chunky
consul config write -http-addr="$DC2" ./docker-configs/configs/exported-services/exported-services-dc2-chunky.hcl