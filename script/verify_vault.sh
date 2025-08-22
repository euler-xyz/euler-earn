#!/bin/bash

# EulerEarn Vault Verification Script
# This script verifies an already deployed EulerEarn vault by extracting constructor arguments
# from the deployment transaction and then verifying the contract

set -e  # Exit on any error

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

# Function to get factory address
get_factory_address() {
    local chain_id="$1"
    local addresses_dir="../euler-interfaces/addresses/$chain_id"
    local core_file="$addresses_dir/CoreAddresses.json"
    
    check_file "$core_file"
    
    local factory_address=$(get_json_value "$core_file" "eulerEarnFactory")
    
    if [ -z "$factory_address" ] || [ "$factory_address" = "null" ] || [ "$factory_address" = "" ]; then
        print_error "EulerEarnFactory address not found in CoreAddresses.json for chain $chain_id"
        exit 1
    fi
    
    echo "$factory_address"
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

# Function to get factory constructor arguments for EulerEarn
get_factory_constructor_args() {
    local chain_id="$1"
    local addresses_dir="../euler-interfaces/addresses/$chain_id"
    
    check_directory "$addresses_dir"
    
    # Define the JSON files and keys for each argument
    local core_file="$addresses_dir/CoreAddresses.json"
    
    check_file "$core_file"
    
    # Get the values
    local evc_address=$(get_json_value "$core_file" "evc")
    local permit2_address=$(get_json_value "$core_file" "permit2")
    
    # Validate that we got all addresses
    if [ -z "$evc_address" ] || [ "$evc_address" = "null" ]; then
        print_error "Failed to get evc address from $core_file"
        exit 1
    fi
    
    if [ -z "$permit2_address" ] || [ "$permit2_address" = "null" ]; then
        print_error "Failed to get permit2 address from $core_file"
        exit 1
    fi
    
    echo "$evc_address|$permit2_address"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 --tx-hash TX_HASH --vault-address VAULT_ADDRESS --rpc-url CHAIN_ID_OR_URL [--verifier VERIFIER_TYPE]"
    echo
    echo "Options:"
    echo "  --tx-hash TX_HASH        Deployment transaction hash"
    echo "  --vault-address ADDRESS  Deployed vault contract address"
    echo "  --rpc-url CHAIN_ID_OR_URL  Chain ID (numeric) or full RPC URL"
    echo "  --verifier TYPE          Verifier type (default: etherscan)"
    echo "                           Supported: etherscan, blockscout, sourcify, custom"
    echo "  -h, --help              Show this help message"
    echo
    echo "Description:"
    echo "  Verifies an already deployed EulerEarn vault by extracting constructor arguments"
    echo "  from the deployment transaction and then verifying the contract."
    echo
    echo "Examples:"
    echo "  $0 --tx-hash 0x1234... --vault-address 0xabcd... --rpc-url 10 --verifier etherscan"
    echo "  $0 --tx-hash 0x1234... --vault-address 0xabcd... --rpc-url https://rpc.example.com --verifier blockscout"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tx-hash)
                tx_hash="$2"
                shift 2
                ;;
            --vault-address)
                vault_address="$2"
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
    if [ -z "$tx_hash" ]; then
        print_error "Missing required argument: --tx-hash"
        show_usage
        exit 1
    fi
    
    if [ -z "$vault_address" ]; then
        print_error "Missing required argument: --vault-address"
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
    print_info "EulerEarn Vault Verification Script (Simplified)"
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
    
    print_info "Using transaction hash: $tx_hash"
    print_info "Using vault address: $vault_address"
    print_info "Using chain ID: $chain_id"
    print_info "Using verifier: $verifier_type"
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
    
    print_info "Getting factory address for chain $chain_id..."
    factory_address=$(get_factory_address "$chain_id")
    print_success "Factory address: $factory_address"
    
    echo
    
    # Extract constructor arguments from the transaction
    print_info "Extracting transaction data for tx: $tx_hash"
    
    # Get transaction data using cast tx
    local tx_data=$(cast tx "$tx_hash" --rpc-url "$rpc_url" --json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to get transaction data for tx: $tx_hash"
        exit 1
    fi
    
    # Extract the input data from the transaction
    local input_data=$(echo "$tx_data" | jq -r '.input' 2>/dev/null)
    
    if [ -z "$input_data" ] || [ "$input_data" = "null" ]; then
        print_error "Failed to extract input data from transaction"
        exit 1
    fi
    
    print_info "Extracted input data: $input_data"
    
    # The input data should be a call to createEulerEarn function
    # Function selector for createEulerEarn: createEulerEarn(address,uint256,address,string,string,bytes32)
    # We need to remove the function selector (first 10 characters = 4 bytes)
    local calldata_without_selector="${input_data:10}"
    
    if [ -z "$calldata_without_selector" ]; then
        print_error "Failed to extract calldata without function selector"
        exit 1
    fi
    
    print_info "Calldata without function selector: $calldata_without_selector"
    
    # Decode the calldata using cast decode-abi
    # Function signature: createEulerEarn(address,uint256,address,string,string,bytes32)
    local decoded_data=$(cast decode-abi --input "createEulerEarn(address,uint256,address,string,string,bytes32)" "$calldata_without_selector" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to decode calldata. This might not be a createEulerEarn transaction."
        exit 1
    fi
    
    print_info "Decoded calldata:"
    echo "$decoded_data"
    
    # Convert the decoded data to an array and extract each parameter
    local decoded_array=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            decoded_array+=("$line")
        fi
    done <<< "$decoded_data"
    
    # Extract parameters by position
    local initial_owner="${decoded_array[0]}"
    local initial_timelock="${decoded_array[1]}"
    local asset="${decoded_array[2]}"
    local name="${decoded_array[3]}"
    local symbol="${decoded_array[4]}"
    local salt="${decoded_array[5]}"
    
    # Validate that we extracted all parameters
    if [ -z "$initial_owner" ] || [ -z "$initial_timelock" ] || [ -z "$asset" ] || [ -z "$name" ] || [ -z "$symbol" ] || [ -z "$salt" ]; then
        print_error "Failed to extract all constructor parameters from decoded data"
        exit 1
    fi
    
    print_success "Successfully extracted constructor parameters:"
    print_info "  initialOwner: $initial_owner"
    print_info "  initialTimelock: $initial_timelock"
    print_info "  asset: $asset"
    print_info "  name: $name"
    print_info "  symbol: $symbol"
    print_info "  salt: $salt"
    
    # Get factory constructor arguments (evc and permit2 addresses)
    print_info "Getting factory constructor arguments for EulerEarn..."
    local factory_args=$(get_factory_constructor_args "$chain_id")
    local evc_address=$(echo "$factory_args" | cut -d'|' -f1)
    local permit2_address=$(echo "$factory_args" | cut -d'|' -f2)
    
    print_success "Factory constructor arguments:"
    print_info "  EVC address: $evc_address"
    print_info "  Permit2 address: $permit2_address"
    
    echo
    
    # Build the constructor arguments for EulerEarn
    # Constructor order: (address owner, address evc, address permit2, uint256 initialTimelock, address _asset, string memory __name, string memory __symbol)
    print_info "Encoding constructor arguments for EulerEarn..."
    
    # Encode the constructor arguments using cast abi-encode
    local constructor_signature="constructor(address,address,address,uint256,address,string,string)"
    local constructor_args_encoded=$(cast abi-encode "$constructor_signature" "$initial_owner" "$evc_address" "$permit2_address" "$initial_timelock" "$asset" "$name" "$symbol")
    
    if [ $? -ne 0 ]; then
        print_error "Failed to encode constructor arguments"
        exit 1
    fi
    
    print_success "Successfully encoded constructor arguments:"
    print_info "  Raw args: $initial_owner $evc_address $permit2_address $initial_timelock $asset $name $symbol"
    print_info "  Encoded: $constructor_args_encoded"
    
    echo
    
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
        verifier_args="$verifier_args --verifier-api-key $verifier_api_key --verifier=etherscan"
    fi
    
    # Verify the contract using forge verify-contract
    print_info "Verifying EulerEarn contract..."
    
    # Build the forge verify command
    local verify_cmd="forge verify-contract $vault_address src/EulerEarn.sol:EulerEarn \
        --chain $chain_id \
        --rpc-url $rpc_url \
        --constructor-args $constructor_args_encoded \
        $verifier_args"
    
    print_info "Executing forge verify command..."
    echo
    
    # Execute the verification
    local temp_output=$(mktemp)
    local exit_code=0
    
    eval "$verify_cmd" 2>&1 | tee "$temp_output"
    exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        print_success "Contract verification completed successfully!"
        
        # Check if verification was successful
        if grep -q "Successfully verified" "$temp_output" || grep -q "Contract is already verified" "$temp_output"; then
            print_success "EulerEarn vault at $vault_address has been verified on chain $chain_id!"
        else
            print_warning "Verification command completed but success message not found in output"
            print_info "Please check the output above for verification status"
        fi
    else
        print_error "Contract verification failed with exit code $exit_code!"
        print_info "Please check the output above for error details"
        rm -f "$temp_output"
        exit $exit_code
    fi
    
    rm -f "$temp_output"
    
    print_success "Verification process completed!"
    print_info "Vault address: $vault_address"
    print_info "Chain ID: $chain_id"
    print_info "Transaction hash: $tx_hash"
}

# Run main function
main "$@" 