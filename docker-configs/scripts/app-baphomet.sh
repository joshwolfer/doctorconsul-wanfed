#!/bin/bash

# ==========================================
#       Register External Services
# ==========================================

echo -e "${GRN}"
echo -e "=========================================="
echo -e "    Register External Baphomet Services"
echo -e "==========================================${NC}"

echo -e "${GRN}DC1/proj1/virtual-baphomet ${NC}"

echo ""
echo -e "${GRN}DC1/Proj1/default/baphomet0:${NC} $(curl -s --request PUT --data @./docker-configs/configs/services/dc1-proj1-baphomet0.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register")"
echo -e "${GRN}DC1/Proj1/default/baphomet1:${NC} $(curl -s --request PUT --data @./docker-configs/configs/services/dc1-proj1-baphomet1.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register")"
echo -e "${GRN}DC1/Proj1/default/baphomet2:${NC} $(curl -s --request PUT --data @./docker-configs/configs/services/dc1-proj1-baphomet2.json --header "X-Consul-Token: root" "${DC1}/v1/catalog/register")"