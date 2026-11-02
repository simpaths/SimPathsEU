// =========================================================================
// DSGE Model - POLAND
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Poland_*.mod.
//
// Usage:  >> dynare Macromodel_Poland use_dll
// =========================================================================

@#define country = "Poland"
@#include "Macromodel_template.mod"
