#!/bin/bash

# ==========================================
#      Unicorn Application Resources
# ==========================================

# ==========================================
#            Admin Partitions
# ==========================================

#  The Unicorn Application admin partition is created immediately by the post-config script so that it doesn't hork the registration of the Consul agents and mesh gateways.
#  If we put it here, it'd probably cause a timing issue.

# ==========================================
#                Namespaces
# ==========================================

echo -e ""
echo -e "${GRN}Create Unicorn NSs in DC1${NC}"
# Create Unicorn NSs in DC1
consul namespace create -name frontend -partition=default -http-addr="$DC1"
consul namespace create -name backend -partition=default -http-addr="$DC1"

echo -e ""
echo -e "${GRN}Create Unicorn NSs in DC2${NC}"
# Create Unicorn NSs in DC2
consul namespace create -name frontend -partition=default -http-addr="$DC2"
consul namespace create -name backend -partition=default -http-addr="$DC2"

# ------------------------------------------
#           proxy-defaults
# ------------------------------------------

#  Proxy defaults already defined in default partition. No non-default partitions so no more proxy - defaults.

# ------------------------------------------
#         Create ACL tokens in DC1
# ------------------------------------------

# Service Token for Node: unicorn-frontend-dc1_envoy
echo -e ""
echo -e "${GRN}ACL Token: 000000004444 (-policy-name=unicorn):${NC}"

consul acl policy create -name unicorn -partition=default -namespace=default -rules @./docker-configs/acl/dc1-unicorn-frontend.hcl

# consul acl token create \
#     -partition=default \
#     -namespace=default \
#     -secret="00000000-0000-0000-0000-000000004444" \
#     -accessor="00000000-0000-0000-0000-000000004444" \
#     -policy-name=unicorn \
#     -http-addr="$DC1"

### ^^^ Temporary scoping of the token to the default namespace to figure out what's broken in cluster peering

consul acl token create \
    -service-identity=unicorn-frontend:dc1 \
    -partition=default \
    -namespace=frontend \
    -secret="00000000-0000-0000-0000-000000004444" \
    -accessor="00000000-0000-0000-0000-000000004444" \
    -http-addr="$DC1"

# ------------------------------------------------------------------------------------ 

# Service Token for Node: unicorn-backend-dc1_envoy. Still broken with SD of peer endpoints. Keep using the temp one above.
echo -e ""
echo -e "${GRN}ACL Token: 000000005555 (unicorn-backend:dc1):${NC}"

consul acl token create \
    -service-identity=unicorn-backend:dc1 \
    -partition=default \
    -namespace=backend \
    -secret="00000000-0000-0000-0000-000000005555" \
    -accessor="00000000-0000-0000-0000-000000005555" \
    -http-addr="$DC1"

# ------------------------------------------------------------------------------------ 

# ------------------------------------------
#        Create ACL tokens in DC2
# ------------------------------------------

# Service Token for Node: unicorn-backend-dc2_envoy
echo -e ""
echo -e "${GRN}ACL Token: 000000006666 (unicorn-backend:dc2):${NC}"

consul acl token create \
    -service-identity=unicorn-backend:dc2 \
    -partition=default \
    -namespace=backend \
    -secret="00000000-0000-0000-0000-000000006666" \
    -accessor="00000000-0000-0000-0000-000000006666" \
    -http-addr="$DC2"

# ------------------------------------------
#   DC1/unicorn cross namespace discovery
# ------------------------------------------

echo -e ""
echo -e "${GRN}Add DC1/unicorn cross-namespace discovery${NC}"

consul acl policy create \
  -name "cross-namespace-sd" \
  -description "cross-namespace service discovery" \
  -rules @./docker-configs/acl/cross-namespace-discovery.hcl \
  -partition=default \
  -namespace=default \
  -http-addr="$DC1"

consul namespace update -name frontend \
  -default-policy-name="cross-namespace-sd" \
  -partition=default \
  -http-addr="$DC1"

# We need this to make is so unicorn-frontend can read unicorn-backend (discovery).
# But this still doesn't grant read into imported services aross partitions. What a pain in the ass.
# I should probably just enable this to all namespaces in every cluster.

# ------------------------------------------
#           service-defaults
# ------------------------------------------

echo -e ""
echo -e "${GRN}service-defaults:${NC}"

# Service Defaults are first, then exports. Per Derek, it's better to set the default before exporting services.

consul config write -http-addr="$DC1" ./docker-configs/configs/service-defaults/unicorn-frontend-defaults.hcl
consul config write -http-addr="$DC1" ./docker-configs/configs/service-defaults/unicorn-backend-defaults.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/service-defaults/unicorn-backend-defaults.hcl

# ------------------------------------------
#              Intentions
# ------------------------------------------

echo -e ""
echo -e "${GRN}Service Intentions:${NC}"

consul config write -http-addr="$DC1" ./docker-configs/configs/intentions/dc1-unicorn_frontend-allow.hcl
consul config write -http-addr="$DC2" ./docker-configs/configs/intentions/dc2-unicorn_frontend-allow.hcl

consul config write -http-addr="$DC1" ./docker-configs/configs/intentions/dc1-unicorn_backend_failover-allow.hcl

# ------------------------------------------
#            Service-Resolvers
# ------------------------------------------

echo -e ""
echo -e "${GRN}Service-resolvers:${NC}"
echo -e "${YELL}no service resolver for now, because it uses peers ${NC}"
# consul config write -http-addr="$DC1" ./docker-configs/configs/service-resolver/dc1-unicorn-backend-failover.hcl
echo -e ""

# ------------------------------------------
#              Sameness Groups
# ------------------------------------------

# Fix SG later

# echo -e ""
# echo -e "${GRN}Sameness Group 'Unicorn':${NC}"
# consul config write -http-addr="$DC1" ./docker-configs/configs/sameness-groups/dc1-unicorn-ssg-unicorn.hcl

# consul config list -kind sameness-group
# consul config read -kind sameness-group -name unicorn
# consul config delete -kind sameness-group -name unicorn


# ------------------------------------------
#             Prepared Query
# ------------------------------------------

curl $DC1/v1/query \
    --request POST \
    --header "X-Consul-Token: root" \
    --data @./docker-configs/configs/prepared_queries/pq-unicorn-sg.json


curl $DC1/v1/query \
    --request POST \
    --header "X-Consul-Token: root" \
    --data @./docker-configs/configs/prepared_queries/pq-unicorn-targets.json


curl $DC1/v1/query \
    --request POST \
    --header "X-Consul-Token: root" \
    --data @./docker-configs/configs/prepared_queries/pq-unicorn-partition.json


  