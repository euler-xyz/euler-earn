/// Maximum total assets per underlying token
definition MAX_ASSETS() returns uint256 = max_uint160;

/// Offsets for the shares <-> assets conversion. Based on OZ ERC4626 implementation.
/// Currently global constants, with possibility to extend those to contract-specific values.
definition SHARES_OFFSET() returns uint256 = 1;
definition ASSETS_OFFSET() returns uint256 = 1;