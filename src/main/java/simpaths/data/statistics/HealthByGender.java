package simpaths.data.statistics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;

import microsim.data.db.PanelEntityKey;
import microsim.statistics.ICollectionFilter;

import simpaths.data.filters.AgeGroupCSfilter;
import simpaths.data.filters.FemaleAgeGroupCSfilter;
import simpaths.data.filters.MaleAgeGroupCSfilter;
import simpaths.model.Person;
import simpaths.model.SimPathsModel;
import simpaths.model.enums.Dhe;
import simpaths.model.enums.Indicator;

/**
 * EU-adapted health statistics entity, broken down by gender (long format).
 *
 * <p>Formerly {@code HealthStatistics}, exported as {@code HealthStatistics1.csv}. It was
 * renamed — contents untouched — when the age-band health columns were split out of the
 * omnibus {@code Statistics2}: this output is stacked long (three rows per year, one per
 * gender subgroup) while those are one wide row per year, so they could not share a file.
 * The wide output now carries the {@link HealthStatistics} name.
 *
 * For the working-age adult population (16-64), records proportions of:
 *   - self-reported health category (Dhe: Poor / Fair / Good / VeryGood / Excellent)
 *   - long-term sick or disabled (Dlltsd == True)
 * broken down by {Total, Male, Female} (one row per gender per time-step).
 *
 * Diverges from the UK version: UK tracks continuous measures
 * (DHM, MCS, PCS, DLS, QALYs, WELLBYs) that do not exist in the EU Person model,
 * so the EU version uses the available ordinal self-rated health enum and the
 * binary disability indicator.
 */
@Entity
public class HealthByGender {

    @Id
    private PanelEntityKey key = new PanelEntityKey(1L);

    @Column(name = "gender")
    private String demSex;

    // self-reported health (Dhe) category proportions
    @Column(name = "prop_dhe_poor")
    private double propDhePoor;

    @Column(name = "prop_dhe_fair")
    private double propDheFair;

    @Column(name = "prop_dhe_good")
    private double propDheGood;

    @Column(name = "prop_dhe_verygood")
    private double propDheVeryGood;

    @Column(name = "prop_dhe_excellent")
    private double propDheExcellent;

    // disability (dlltsd) proportion
    @Column(name = "prop_disabled")
    private double propDisabled;

    // observation counts
    @Column(name = "N_total")
    private int nObsTotal;

    @Column(name = "N_validDhe")
    private int nObsValidDhe;

    @Column(name = "N_validDlltsd")
    private int nObsValidDlltsd;


    // Getters / setters

    public String getGender() { return demSex; }
    public void setGender(String demSex) { this.demSex = demSex; }

    public double getPropDhePoor() { return propDhePoor; }
    public void setPropDhePoor(double v) { this.propDhePoor = v; }

    public double getPropDheFair() { return propDheFair; }
    public void setPropDheFair(double v) { this.propDheFair = v; }

    public double getPropDheGood() { return propDheGood; }
    public void setPropDheGood(double v) { this.propDheGood = v; }

    public double getPropDheVeryGood() { return propDheVeryGood; }
    public void setPropDheVeryGood(double v) { this.propDheVeryGood = v; }

    public double getPropDheExcellent() { return propDheExcellent; }
    public void setPropDheExcellent(double v) { this.propDheExcellent = v; }

    public double getPropDisabled() { return propDisabled; }
    public void setPropDisabled(double v) { this.propDisabled = v; }

    public int getN_total() { return nObsTotal; }
    public void setN_total(int n) { this.nObsTotal = n; }

    public int getN_validDhe() { return nObsValidDhe; }
    public void setN_validDhe(int n) { this.nObsValidDhe = n; }

    public int getN_validDlltsd() { return nObsValidDlltsd; }
    public void setN_validDlltsd(int n) { this.nObsValidDlltsd = n; }


    /**
     * Recompute all statistics for the requested gender subgroup.
     *
     * @param model      the simulation model
     * @param gender_s   one of "Total", "Male", "Female"
     */
    public void update(SimPathsModel model, String gender_s) {

        setGender(gender_s);

        // Select working-age filter for the requested gender subgroup.
        // EU has no AgeGenderCSfilter; compose from existing gender-specific age filters.
        final ICollectionFilter filter;
        if ("Male".equals(gender_s)) {
            filter = new MaleAgeGroupCSfilter(16, 64);
        } else if ("Female".equals(gender_s)) {
            filter = new FemaleAgeGroupCSfilter(16, 64);
        } else {
            filter = new AgeGroupCSfilter(16, 64);
        }

        int nTotal = 0;
        int nValidDhe = 0;
        int nValidDlltsd = 0;
        int nPoor = 0, nFair = 0, nGood = 0, nVeryGood = 0, nExcellent = 0;
        int nDisabled = 0;

        for (Person person : model.getPersons()) {
            if (!filter.isFiltered(person)) continue;
            nTotal++;

            Dhe dhe = person.getDhe();
            if (dhe != null) {
                nValidDhe++;
                switch (dhe) {
                    case Poor:      nPoor++;      break;
                    case Fair:      nFair++;      break;
                    case Good:      nGood++;      break;
                    case VeryGood:  nVeryGood++;  break;
                    case Excellent: nExcellent++; break;
                }
            }

            Indicator dlltsd = person.getDlltsd();
            if (dlltsd != null) {
                nValidDlltsd++;
                if (Indicator.True.equals(dlltsd)) {
                    nDisabled++;
                }
            }
        }

        setN_total(nTotal);
        setN_validDhe(nValidDhe);
        setN_validDlltsd(nValidDlltsd);

        // Proportions: NaN when denominator is zero (makes missing-data states visible in CSV).
        setPropDhePoor(      nValidDhe > 0 ? (double) nPoor      / nValidDhe : Double.NaN);
        setPropDheFair(      nValidDhe > 0 ? (double) nFair      / nValidDhe : Double.NaN);
        setPropDheGood(      nValidDhe > 0 ? (double) nGood      / nValidDhe : Double.NaN);
        setPropDheVeryGood(  nValidDhe > 0 ? (double) nVeryGood  / nValidDhe : Double.NaN);
        setPropDheExcellent( nValidDhe > 0 ? (double) nExcellent / nValidDhe : Double.NaN);
        setPropDisabled(     nValidDlltsd > 0 ? (double) nDisabled / nValidDlltsd : Double.NaN);
    }
}
