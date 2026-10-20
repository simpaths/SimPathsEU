package simpaths.model;

import simpaths.model.enums.Occupancy;
import simpaths.model.enums.OccupancyExtended;

/**
 * The single definition of which {@link OccupancyExtended} subgroup a
 * {@link BenefitUnit} belongs to.
 *
 * <p><b>Why this class exists.</b> The classification lived twice: once in
 * {@code ActivityAlignmentV2.matchesSubgroup}, which decides the population the
 * alignment actually operates on, and once in
 * {@code AlignmentAdjustmentFactors.classifyBenefitUnit}, which counts the
 * population the alignment diagnostics report. The second was documented as
 * "mirrors the matchesSubgroup logic" — and had already stopped doing so.</p>
 *
 * <p>The divergence was at a missing member. {@code matchesSubgroup} derived the
 * adult-child flag as 0 when the {@code Single_Male} unit's male was null, and
 * {@code acFlag != 1} then admitted the unit to {@code Single_Male};
 * {@code classifyBenefitUnit} required {@code male != null} and dropped the unit
 * entirely. So a diagnostic that claimed to describe the aligned population could
 * describe a different one, with no error anywhere.</p>
 *
 * <p>This class resolves it the null-safe way — a unit whose occupancy names a
 * member that does not exist belongs to no subgroup. In the live model that case
 * is unreachable, because {@link BenefitUnit#getOccupancy()} derives the
 * occupancy <em>from</em> the members; it is reachable only through the
 * {@code i_demOccupancy} path used outside a running model. Behaviour for every
 * well-formed benefit unit is unchanged.</p>
 */
public final class BenefitUnitSubgroup {

    private BenefitUnitSubgroup() {
    }

    /**
     * @return the subgroup this benefit unit belongs to, or null if it belongs
     *         to none (including the malformed case of an occupancy naming an
     *         absent member)
     */
    public static OccupancyExtended classify(BenefitUnit bu) {
        Occupancy occ = bu.getOccupancy();
        Person male = bu.getMale();
        Person female = bu.getFemale();
        boolean maleAtRisk = (male != null) && male.atRiskOfWork();
        boolean femaleAtRisk = (female != null) && female.atRiskOfWork();

        if (occ == Occupancy.Couple) {
            if (maleAtRisk && femaleAtRisk) return OccupancyExtended.Couple;
            if (maleAtRisk) return OccupancyExtended.Male_With_Dependent;
            if (femaleAtRisk) return OccupancyExtended.Female_With_Dependent;
            return null;
        }
        if (occ == Occupancy.Single_Male && male != null) {
            return (male.getAdultChildFlag() == 1)
                    ? OccupancyExtended.Male_AC
                    : OccupancyExtended.Single_Male;
        }
        if (occ == Occupancy.Single_Female && female != null) {
            return (female.getAdultChildFlag() == 1)
                    ? OccupancyExtended.Female_AC
                    : OccupancyExtended.Single_Female;
        }
        return null;
    }

    /** True when the benefit unit belongs to {@code subgroup}. */
    public static boolean matches(BenefitUnit bu, OccupancyExtended subgroup) {
        return classify(bu) == subgroup;
    }
}
