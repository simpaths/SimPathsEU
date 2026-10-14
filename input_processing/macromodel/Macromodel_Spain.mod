// =========================================================================
// DSGE Model - SPAIN
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Spain_*.mod.
//
// Usage:  >> dynare Macromodel_Spain use_dll
// =========================================================================

@#define country = "Spain"
@#include "Macromodel_template.mod"
