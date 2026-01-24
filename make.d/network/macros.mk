# network-macros.mk - Network helper macros (@codebase)
# Self-guarding include for macro definitions

ifndef make.d/network/macros.mk
make.d/network/macros.mk := make.d/network/macros.mk

# =============================================================================
# NETWORK IP ADDRESS DERIVATION MACROS
# =============================================================================

# Extract IP address from CIDR format (e.g., 10.80.23.0/24 -> 10.80.23.0)
.network.to-inet = $(word 1,$(subst /, ,$(1)))

# Strip single quotes ipcalc emits in shell mode
.network.strip = $(subst ',,$(strip $(1)))

# Break an inet into base and last octet helpers
.network.inetaddr.base3 = $(word 1,$(subst ., ,$(1))).$(word 2,$(subst ., ,$(1))).$(word 3,$(subst ., ,$(1)))
.network.inetaddr.last = $(word 4,$(subst ., ,$(1)))
.network.inetaddr.add-last = $(call .network.inetaddr.base3,$(1)).$(call plus,$(call .network.inetaddr.last,$(1)),$(2))

# Gateway IP for a subnet (HOST_MIN from ipcalc is the gateway)
# Inputs: 1=subnet type (lowercase), 2=subnet index
.network.subnet-gateway-inetaddr = $(call .network.strip,$(.network.$(1).split.$(2).minaddr))

# Derive host IP from ipcalc-emitted HOST_MIN with a relative offset
# Inputs: 1=subnet type, 2=subnet index, 3=offset from host_min (0 => host_min)
.network.subnet-host-inetaddr = $(call .network.inetaddr.add-last,$(call .network.subnet-gateway-inetaddr,$(1),$(2)),$(3))

# Extract base IP from CIDR (first 3 octets) for DHCP reservations
# Usage: $(call .network.cidr.to-base-inetaddr,CIDR) - e.g., $(call .network.cidr.to-base-inetaddr.,10.80.16.0/21) -> 10.80.16
# Strip ipcalc-emitted quotes before splitting to avoid unterminated strings in downstream env files
.network.cidr.to-base-inetaddr = $(call .network.inetaddr.base3,$(call .network.to-inet,$(call .network.strip,$(1))))

endif
