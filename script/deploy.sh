#!/bin/bash

# EulerEarn Factory and PublicAllocator Deployment Script
# This script handles the deployment of both contracts with proper input mappings

set -e  # Exit on any error

# Constants
ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        print_error "File not found: $1"
        exit 1
    fi
}

# Function to check if a directory exists
check_directory() {
    if [ ! -d "$1" ]; then
        print_error "Directory not found: $1"
        exit 1
    fi
}

# Function to get value from JSON file
get_json_value() {
    local file_path="$1"
    local key="$2"
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$key" "$file_path" 2>/dev/null
    else
        print_warning "jq not found, using grep fallback for key: $key"
        grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file_path" | sed 's/.*"\([^"]*\)".*/\1/' 2>/dev/null || echo ""
    fi
}

# Function to load environment variables
load_env() {
    local env_file="../evk-periphery/.env"
    check_file "$env_file"
    
    # Source the environment file
    set -a
    source "$env_file"
    set +a
}

# Function to get RPC URL and chain ID
get_rpc_url_and_chain_id() {
    local input="$1"
    local rpc_url=""
    local extracted_chain_id=""
    
    # Check if input looks like a URL
    if [[ "$input" =~ ^https?:// ]]; then
        # Input is a URL, use it directly and extract chain ID
        rpc_url="$input"
        
        # Extract chain ID using cast
        if command -v cast >/dev/null 2>&1; then
            extracted_chain_id=$(cast chain-id --rpc-url "$rpc_url" 2>/dev/null)
            
            if [ -z "$extracted_chain_id" ] || [ "$extracted_chain_id" = "null" ]; then
                print_error "Failed to extract chain ID from RPC URL"
                exit 1
            fi
        else
            print_error "cast command not found. Please install foundry to extract chain ID from RPC URL"
            exit 1
        fi
    else
        # Input is a chain ID, get RPC URL from environment
        extracted_chain_id="$input"
        
        # Validate chain ID is numeric
        if ! [[ "$extracted_chain_id" =~ ^[0-9]+$ ]]; then
            print_error "Chain ID must be a number when not providing a full RPC URL"
            exit 1
        fi
        
        local env_var="DEPLOYMENT_RPC_URL_$extracted_chain_id"
        rpc_url="${!env_var}"
        
        if [ -z "$rpc_url" ]; then
            print_error "RPC URL not found for chain ID $extracted_chain_id. Check if $env_var is set in ../evk-periphery/.env"
            exit 1
        fi
    fi
    
    # Return both values in a format we can parse
    echo "$rpc_url|$extracted_chain_id"
}

# Function to get verifier URL
get_verifier_url() {
    local chain_id="$1"
    local env_var="VERIFIER_URL_$chain_id"
    local verifier_url="${!env_var}"
    
    if [ -z "$verifier_url" ]; then
        print_error "Verifier URL not found for chain ID $chain_id. Check if $env_var is set in ../evk-periphery/.env"
        exit 1
    fi
    
    echo "$verifier_url"
}

# Function to get verifier API key
get_verifier_api_key() {
    local chain_id="$1"
    local env_var="VERIFIER_API_KEY_$chain_id"
    local api_key="${!env_var}"
    
    if [ -z "$api_key" ]; then
        print_error "Verifier API key not found for chain ID $chain_id. Check if $env_var is set in ../evk-periphery/.env"
        exit 1
    fi
    
    echo "$api_key"
}

# Function to get factory constructor arguments
get_factory_constructor_args() {
    local chain_id="$1"
    local addresses_dir="../euler-interfaces/addresses/$chain_id"
    
    check_directory "$addresses_dir"
    
    # Define the JSON files and keys for each argument
    local multisig_file="$addresses_dir/MultisigAddresses.json"
    local core_file="$addresses_dir/CoreAddresses.json"
    local periphery_file="$addresses_dir/PeripheryAddresses.json"
    
    check_file "$multisig_file"
    check_file "$core_file"
    check_file "$periphery_file"
    
    # Get the values
    local dao_address=$(get_json_value "$multisig_file" "DAO")
    local evc_address=$(get_json_value "$core_file" "evc")
    local permit2_address=$(get_json_value "$core_file" "permit2")
    local evk_factory_perspective=$(get_json_value "$periphery_file" "evkFactoryPerspective")
    
    # Validate that we got all addresses
    if [ -z "$dao_address" ] || [ "$dao_address" = "null" ]; then
        print_error "Failed to get DAO address from $multisig_file"
        exit 1
    fi
    
    if [ -z "$evc_address" ] || [ "$evc_address" = "null" ]; then
        print_error "Failed to get evc address from $core_file"
        exit 1
    fi
    
    if [ -z "$permit2_address" ] || [ "$permit2_address" = "null" ]; then
        print_error "Failed to get permit2 address from $core_file"
        exit 1
    fi
    
    if [ -z "$evk_factory_perspective" ] || [ "$evk_factory_perspective" = "null" ]; then
        print_error "Failed to get evkFactoryPerspective address from $periphery_file"
        exit 1
    fi
    
    echo "$dao_address $evc_address $permit2_address $evk_factory_perspective"
}

# Function to check if contract is already deployed
check_contract_deployed() {
    local chain_id="$1"
    local contract_key="$2"
    local addresses_dir="../euler-interfaces/addresses/$chain_id"
    local file_name="$3"
    local file_path="$addresses_dir/$file_name"
    
    if [ -f "$file_path" ]; then
        local existing_address=$(get_json_value "$file_path" "$contract_key")
        if [ -n "$existing_address" ] && [ "$existing_address" != "null" ] && [ "$existing_address" != "" ] && [ "$existing_address" != "$ZERO_ADDRESS" ]; then
            echo "$existing_address"
            return 0
        fi
    fi
    
    return 1
}

# Function to update CoreAddresses.json
update_core_addresses() {
    local chain_id="$1"
    local deployed_address="$2"
    local addresses_dir="../euler-interfaces/addresses/$chain_id"
    local core_file="$addresses_dir/CoreAddresses.json"
    
    print_info "Updating CoreAddresses.json with deployed address..."
    
    # Check if jq is available for JSON manipulation
    if command -v jq >/dev/null 2>&1; then
        # Update the JSON file: add eulerEarnFactory, remove eulerEarnImplementation if it exists
        if jq --arg addr "$deployed_address" '
            .eulerEarnFactory = $addr | 
            del(.eulerEarnImplementation // empty)
        ' "$core_file" > "${core_file}.tmp" && mv "${core_file}.tmp" "$core_file"; then
            print_success "Successfully updated CoreAddresses.json"
            print_info "Added eulerEarnFactory: $deployed_address"
            print_info "Removed eulerEarnImplementation if it existed"
        else
            print_error "Failed to update CoreAddresses.json with jq"
            exit 1
        fi
    else
        print_warning "jq not found, attempting manual JSON update..."
        
        # Manual JSON update using sed (less robust but works for simple cases)
        local temp_file="${core_file}.tmp"
        
        # Remove eulerEarnImplementation line if it exists
        grep -v '"eulerEarnImplementation"' "$core_file" > "$temp_file"
        
        # Add eulerEarnFactory before the closing brace
        sed -i.bak '$ s/}$/,\n    "eulerEarnFactory": "'"$deployed_address"'"\n}/' "$temp_file"
        
        if [ $? -eq 0 ]; then
            mv "$temp_file" "$core_file"
            rm -f "${temp_file}.bak"
            print_success "Successfully updated CoreAddresses.json manually"
            print_info "Added eulerEarnFactory: $deployed_address"
            print_info "Removed eulerEarnImplementation if it existed"
        else
            print_error "Failed to update CoreAddresses.json manually"
            exit 1
        fi
    fi
}

# Function to update PeripheryAddresses.json
update_periphery_addresses() {
    local chain_id="$1"
    local deployed_address="$2"
    local addresses_dir="../euler-interfaces/addresses/$chain_id"
    local periphery_file="$addresses_dir/PeripheryAddresses.json"
    
    print_info "Updating PeripheryAddresses.json with deployed address..."
    
    # Check if jq is available for JSON manipulation
    if command -v jq >/dev/null 2>&1; then
        # Update the JSON file: add eulerEarnPublicAllocator
        if jq --arg addr "$deployed_address" '
            .eulerEarnPublicAllocator = $addr
        ' "$periphery_file" > "${periphery_file}.tmp" && mv "${periphery_file}.tmp" "$periphery_file"; then
            print_success "Successfully updated PeripheryAddresses.json"
            print_info "Added eulerEarnPublicAllocator: $deployed_address"
        else
            print_error "Failed to update PeripheryAddresses.json with jq"
            exit 1
        fi
    else
        print_warning "jq not found, attempting manual JSON update..."
        
        # Manual JSON update using sed (less robust but works for simple cases)
        local temp_file="${periphery_file}.tmp"
        
        # Add eulerEarnPublicAllocator before the closing brace
        sed -i.bak '$ s/}$/,\n    "eulerEarnPublicAllocator": "'"$deployed_address"'"\n}/' "$temp_file"
        
        if [ $? -eq 0 ]; then
            mv "$temp_file" "$periphery_file"
            rm -f "${temp_file}.bak"
            print_success "Successfully updated PeripheryAddresses.json manually"
            print_info "Added eulerEarnPublicAllocator: $deployed_address"
        else
            print_error "Failed to update PeripheryAddresses.json manually"
            exit 1
        fi
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 --account ACCOUNT --rpc-url CHAIN_ID_OR_URL [--verifier VERIFIER_TYPE]"
    echo
    echo "Options:"
    echo "  --account ACCOUNT      Deployer account name"
    echo "  --rpc-url CHAIN_ID_OR_URL  Chain ID (numeric) or full RPC URL"
    echo "  --verifier TYPE        Verifier type (default: etherscan)"
    echo "                         Supported: etherscan, blockscout, sourcify, custom"
    echo "  -h, --help            Show this help message"
    echo
    echo "Description:"
    echo "  Deploys EulerEarnFactory and PublicAllocator contracts if not already deployed."
    echo "  Checks existing deployments and skips if contracts are already present."
    echo
    echo "Examples:"
    echo "  $0 --account DEPLOYER_OP --rpc-url 10 --verifier etherscan"
    echo "  $0 --account DEPLOYER_OP --rpc-url https://rpc.example.com --verifier blockscout"
    echo "  $0 --account DEPLOYER_OP --rpc-url 10 --verifier sourcify"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --account)
                deployer_account="$2"
                shift 2
                ;;
            --rpc-url)
                chain_id="$2"
                shift 2
                ;;
            --verifier)
                verifier_type="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$deployer_account" ]; then
        print_error "Missing required argument: --account"
        show_usage
        exit 1
    fi
    
    if [ -z "$chain_id" ]; then
        print_error "Missing required argument: --rpc-url"
        show_usage
        exit 1
    fi
    
    # Validate chain ID is numeric (only if it's not a URL)
    if ! [[ "$chain_id" =~ ^[0-9]+$ ]] && ! [[ "$chain_id" =~ ^https?:// ]]; then
        print_error "Chain ID must be a number when not providing a full RPC URL"
        exit 1
    fi
    
    # Set default verifier type if not provided
    verifier_type=${verifier_type:-etherscan}
}

# Main script
main() {
    print_info "EulerEarn Factory and PublicAllocator Deployment Script"
    echo
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check if we're in the right directory
    if [ ! -f "foundry.toml" ]; then
        print_error "This script must be run from the euler-earn-new directory (where foundry.toml is located)"
        exit 1
    fi
    
    # Load environment variables
    print_info "Loading environment variables..."
    load_env
    print_success "Environment variables loaded"
    
    print_info "Using account: $deployer_account"
    print_info "Using chain ID: $chain_id"
    print_info "Using verifier: $verifier_type"
    echo
    
    echo
    
    # Get all required values
    print_info "Getting RPC URL and chain ID..."
    local result=$(get_rpc_url_and_chain_id "$chain_id")
    rpc_url=$(echo "$result" | cut -d'|' -f1)
    chain_id=$(echo "$result" | cut -d'|' -f2)
    print_success "RPC URL: $rpc_url"
    print_success "Chain ID: $chain_id"
    
    print_info "Getting verifier URL for chain $chain_id..."
    verifier_url=$(get_verifier_url "$chain_id")
    print_success "Verifier URL: $verifier_url"
    
    # Only get API key if the verifier type needs it
    if [[ $verifier_type == "blockscout" || $verifier_type == "sourcify" || $verifier_type == "custom" ]]; then
        print_info "Skipping API key retrieval for $verifier_type verifier"
        verifier_api_key=""
    else
        print_info "Getting verifier API key for chain $chain_id..."
        verifier_api_key=$(get_verifier_api_key "$chain_id")
        print_success "Verifier API key: ***${verifier_api_key: -4}"
    fi
    
    print_info "Getting factory constructor arguments for chain $chain_id..."
    constructor_args=$(get_factory_constructor_args "$chain_id")
    print_success "Constructor arguments: $constructor_args"
    
    echo
    
    # Check if contracts are already deployed
    print_info "Checking for existing deployments..."
    
    # Check for old version (eulerEarnImplementation)
    local old_implementation=$(get_json_value "../euler-interfaces/addresses/$chain_id/CoreAddresses.json" "eulerEarnImplementation")
    if [ -n "$old_implementation" ] && [ "$old_implementation" != "null" ] && [ "$old_implementation" != "$ZERO_ADDRESS" ]; then
        print_info "Old EulerEarn implementation found at: $old_implementation"
        print_info "This indicates an old version is deployed. Will deploy new contracts."
    fi
    
    local existing_factory=$(check_contract_deployed "$chain_id" "eulerEarnFactory" "CoreAddresses.json")
    local existing_allocator=$(check_contract_deployed "$chain_id" "eulerEarnPublicAllocator" "PeripheryAddresses.json")
    
    if [ -n "$existing_factory" ]; then
        print_info "EulerEarnFactory already deployed at: $existing_factory"
    else
        print_info "EulerEarnFactory not found, will deploy"
    fi
    
    if [ -n "$existing_allocator" ]; then
        print_info "PublicAllocator already deployed at: $existing_allocator"
    else
        print_info "PublicAllocator not found, will deploy"
    fi
    
    # If both new contracts are already deployed, exit
    if [ -n "$existing_factory" ] && [ -n "$existing_allocator" ]; then
        print_success "Both new contracts are already deployed. Nothing to do."
        exit 0
    fi
    
    # If old implementation exists, we need to deploy new contracts regardless
    if [ -n "$old_implementation" ] && [ "$old_implementation" != "null" ] && [ "$old_implementation" != "$ZERO_ADDRESS" ]; then
        print_info "Old implementation detected. Proceeding with new contract deployment to upgrade."
    fi
    
    echo
    
    # Prompt for account password before building the command
    read -s -p "Enter account password: " account_password
    echo
    if [ -z "$account_password" ]; then
        print_error "Account password is required"
        exit 1
    fi
    
    # Build verifier arguments based on verifier type
    local verifier_args="--verifier-url $verifier_url"
    
    if [[ $verifier_type == "blockscout" ]]; then
        verifier_args="$verifier_args --verifier-api-key \"\" --verifier=blockscout"
    elif [[ $verifier_type == "sourcify" ]]; then
        verifier_args="$verifier_args --verifier=$verifier_type --retries 1"
    elif [[ $verifier_type == "custom" ]]; then
        verifier_args="$verifier_args --verifier=$verifier_type"
    else
        # Default to etherscan and other verifiers that need API key
        verifier_args="$verifier_args --verifier-api-key $verifier_api_key --verifier=$verifier_type"
    fi
    
    # Deploy EulerEarnFactory if not already deployed OR if old implementation exists (upgrade scenario)
    if [ -z "$existing_factory" ] || ([ -n "$old_implementation" ] && [ "$old_implementation" != "null" ] && [ "$old_implementation" != "$ZERO_ADDRESS" ]); then
        print_info "Deploying EulerEarnFactory..."
        
        # Build the forge command for factory
        local factory_cmd="forge create EulerEarnFactory \
            --account $deployer_account \
            --password $account_password \
            --rpc-url $rpc_url \
            --legacy \
            --verify \
            $verifier_args \
            --broadcast \
            --constructor-args $constructor_args"
        
        print_info "Executing forge command for factory..."
        echo
        
        # Execute the factory deployment
        local temp_output=$(mktemp)
        local exit_code=0
        
        eval "$factory_cmd" 2>&1 | tee "$temp_output"
        exit_code=${PIPESTATUS[0]}
        
        if [ $exit_code -eq 0 ]; then
            print_success "Factory deployment completed successfully!"
            
            # Extract deployed address from output
            local deployed_address=$(grep "Deployed to:" "$temp_output" | sed 's/Deployed to: //')
            
            if [ -n "$deployed_address" ]; then
                print_info "Extracted factory address: $deployed_address"
                update_core_addresses "$chain_id" "$deployed_address"
                existing_factory="$deployed_address"
            else
                print_warning "Could not extract factory address from output"
                rm -f "$temp_output"
                exit 1
            fi
        else
            print_error "Factory deployment failed with exit code $exit_code!"
            rm -f "$temp_output"
            exit $exit_code
        fi
        
        rm -f "$temp_output"
    fi
    
    # Deploy PublicAllocator if not already deployed
    if [ -z "$existing_allocator" ]; then
        print_info "Deploying PublicAllocator..."
        
        # Get EVC address for PublicAllocator constructor
        local evc_address=$(get_json_value "../euler-interfaces/addresses/$chain_id/CoreAddresses.json" "evc")
        if [ -z "$evc_address" ] || [ "$evc_address" = "null" ] || [ "$evc_address" = "$ZERO_ADDRESS" ]; then
            print_error "EVC address not found in CoreAddresses.json. Cannot deploy PublicAllocator."
            exit 1
        fi
        
        print_info "Using EVC address for PublicAllocator: $evc_address"
        
        # Build the forge command for allocator
        local allocator_cmd="forge create PublicAllocator \
            --account $deployer_account \
            --password $account_password \
            --rpc-url $rpc_url \
            --legacy \
            --verify \
            $verifier_args \
            --broadcast \
            --constructor-args $evc_address"
        
        print_info "Executing forge command for allocator..."
        echo
        
        # Execute the allocator deployment
        local temp_output=$(mktemp)
        local exit_code=0
        
        eval "$allocator_cmd" 2>&1 | tee "$temp_output"
        exit_code=${PIPESTATUS[0]}
        
        if [ $exit_code -eq 0 ]; then
            print_success "Allocator deployment completed successfully!"
            
            # Extract deployed address from output
            local deployed_address=$(grep "Deployed to:" "$temp_output" | sed 's/Deployed to: //')
            
            if [ -n "$deployed_address" ]; then
                print_info "Extracted allocator address: $deployed_address"
                update_periphery_addresses "$chain_id" "$deployed_address"
            else
                print_warning "Could not extract allocator address from output"
                rm -f "$temp_output"
                exit 1
            fi
        else
            print_error "Allocator deployment failed with exit code $exit_code!"
            rm -f "$temp_output"
            exit $exit_code
        fi
        
        rm -f "$temp_output"
    fi
    
    print_success "All deployments completed successfully!"
    
    # Show deployment summary
    if [ -n "$old_implementation" ] && [ "$old_implementation" != "null" ] && [ "$old_implementation" != "$ZERO_ADDRESS" ]; then
        print_info "Upgraded from old EulerEarn implementation at: $old_implementation"
    fi
    
    if [ -n "$existing_factory" ]; then
        print_info "Factory was already deployed at: $existing_factory"
    fi
    if [ -n "$existing_allocator" ]; then
        print_info "Allocator was already deployed at: $existing_allocator"
    fi
}

# Run main function
main "$@" 