// =========================================================================
// DSGE Model - SWEDEN
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Sweden_*.mod.
//
// Usage:  >> dynare Macromodel_Sweden use_dll
// =========================================================================

@#define country = "Sweden"
@#include "Macromodel_template.mod"
