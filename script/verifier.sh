#!/bin/bash

# Sourced by deploy.sh and verify_vault.sh, which define the print_* helpers.
# Keep in line with evk-periphery's script/utils/verifyContracts.sh.

# VERIFIER_URL overrides VERIFIER_URL_<chain id>
get_verifier_url() {
    local chain_id="$1"
    local env_var="VERIFIER_URL_$chain_id"
    local verifier_url="${VERIFIER_URL:-${!env_var}}"

    if [ -z "$verifier_url" ]; then
        print_error "Verifier URL not found for chain ID $chain_id. Set VERIFIER_URL or $env_var in ../evk-periphery/.env"
        exit 1
    fi

    echo "$verifier_url"
}

# VERIFIER_API_KEY pairs with VERIFIER_URL
get_verifier_api_key() {
    local chain_id="$1"
    local env_var="VERIFIER_API_KEY_$chain_id"

    if [ -n "$VERIFIER_URL" ]; then
        echo "$VERIFIER_API_KEY"
    else
        echo "${!env_var}"
    fi
}

resolve_verifier() {
    local chain_id="$1"

    print_info "Getting verifier URL for chain $chain_id..."
    verifier_url=$(get_verifier_url "$chain_id") || exit 1
    print_success "Verifier URL: $verifier_url"

    # Foundry's chain registry doesn't know Monad (143), so evk-periphery verifies there with the custom verifier against Etherscan V2
    if [[ $chain_id == "143" && $verifier_type == "etherscan" ]]; then
        verifier_type="custom"
        print_info "Using the custom verifier for chain 143"
    fi

    verifier_api_key=$(get_verifier_api_key "$chain_id")
    if [ -n "$verifier_api_key" ]; then
        print_success "Verifier API key: ***${verifier_api_key: -4}"
    elif [[ $verifier_type != "blockscout" && $verifier_type != "sourcify" && $verifier_type != "custom" ]]; then
        print_error "Verifier API key not found for chain ID $chain_id. Set VERIFIER_API_KEY_$chain_id (or VERIFIER_API_KEY with VERIFIER_URL) in ../evk-periphery/.env"
        exit 1
    fi
}

verify_contract() {
    local contract_address="$1"
    local contract_name="$2"
    local encoded_constructor_args="$3"
    local url="$verifier_url"
    local verifier_args

    if [[ $verifier_type == "blockscout" ]]; then
        verifier_args=(--verifier-api-key "" --verifier=blockscout)
    elif [[ $verifier_type == "sourcify" ]]; then
        verifier_args=(--verifier=sourcify --retries 1)
    elif [[ $verifier_type == "custom" ]]; then
        # Foundry's custom verifier ignores --verifier-api-key, so a configured key travels in the URL
        if [ -n "$verifier_api_key" ]; then
            local key_separator="?"
            [[ "$url" == *"?"* ]] && key_separator="&"
            url="${url}${key_separator}apikey=${verifier_api_key}"
        fi
        verifier_args=(--verifier=custom)
    else
        verifier_args=(--verifier-api-key "$verifier_api_key" --verifier="$verifier_type")
    fi

    print_info "Verifying $contract_name at $contract_address..."
    echo

    local temp_output=$(mktemp)
    local exit_code=0

    VERIFIER_API_KEY="$verifier_api_key" ETHERSCAN_API_KEY="$verifier_api_key" forge verify-contract \
        "$contract_address" "$contract_name" \
        --constructor-args "$encoded_constructor_args" \
        --rpc-url "$rpc_url" \
        --chain "$chain_id" \
        --verifier-url "$url" \
        "${verifier_args[@]}" \
        --watch 2>&1 | tee "$temp_output"
    exit_code=${PIPESTATUS[0]}

    if [[ $verifier_type == "sourcify" ]] && grep -q "is already partially verified" "$temp_output"; then
        exit_code=0
    fi

    rm -f "$temp_output"

    if [ $exit_code -ne 0 ]; then
        print_warning "$contract_name at $contract_address is not verified (constructor args: $encoded_constructor_args)"
        return 1
    fi

    print_success "$contract_name verified"
}
