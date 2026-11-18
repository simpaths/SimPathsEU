// =========================================================================
// DSGE Model - GERMANY
// =========================================================================
// Thin wrapper: defines country and includes shared template.
// All structural equations are in Macromodel_template.mod.
// Country-specific parameters are in country_params/Germany_*.mod.
//
// Usage:  >> dynare Macromodel_Germany use_dll
// =========================================================================

@#define country = "Germany"
@#include "Macromodel_template.mod"
