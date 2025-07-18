import "dispatching_EulerEarn.spec";

methods {
}

use builtin rule sanity filtered { f -> f.contract == currentContract 
&& f.selector != sig:multicall(bytes[]).selector
}
