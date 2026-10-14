package simpaths.model.enums;

/**
 * Which realized labour-supply margins SimPaths feeds back into the yearly Ramsey re-solve,
 * selected by the {@code mm_ramseyFeedbackMargins} config key.
 *
 * <p>The planner's labour input is {@code N*h}, so a one percent hours gap dilutes capital
 * exactly as a one percent employment gap does and neither margin has priority. The two
 * single-margin modes decompose the channel: an unrevised re-solve reproduces the standing
 * path, because the terminal tail is a fixed quarter count appended to a slice that shrinks
 * by exactly the quarters already consumed, so the absolute terminal date does not move.
 * The decomposition is not additive -- the Ramsey solution is nonlinear in the labour path.</p>
 *
 * <p>Inert unless {@link MacroModelMode#usesRamseyTrend()}; the re-solve needs a solved
 * Ramsey path to revise.</p>
 */
public enum MacroFeedbackMargins {

    /** Top-down coupling: the planner never sees realized labour supply. */
    NONE,

    /** Feed back realized employment only; the planner keeps its projected hours path. */
    EMPLOYMENT,

    /** Feed back realized hours per worker only; the planner keeps its projected employment. */
    HOURS,

    /** Feed back both margins. */
    EMPLOYMENT_AND_HOURS;

    public boolean isOn() {
        return this != NONE;
    }

    public boolean feedsEmployment() {
        return this == EMPLOYMENT || this == EMPLOYMENT_AND_HOURS;
    }

    public boolean feedsHours() {
        return this == HOURS || this == EMPLOYMENT_AND_HOURS;
    }

    public static MacroFeedbackMargins fromConfigValue(Object raw) {
        return ConfigEnumValue.parse(MacroFeedbackMargins.class, raw, NONE, "mm_ramseyFeedbackMargins");
    }
}
