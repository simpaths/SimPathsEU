package simpaths.data.statistics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;

import microsim.data.db.PanelEntityKey;

/**
 * Health statistics by age band: mean self-rated health score and the share long-term
 * sick or disabled. One row per simulated year, exported to {@code HealthStatistics.csv}.
 *
 * <p>These six columns came out of the omnibus {@code Statistics2} (see
 * {@link DemographicStatistics}) and are fed from the shared {@link AgeBandAggregates}.
 *
 * <p>They could not simply be added to the pre-existing {@code HealthStatistics}, which is
 * written three times per year — once each for Total, Male and Female — and so is stacked
 * long, whereas these are one wide row per year; as plain columns they would repeat one
 * value across all three gender rows. That long output was therefore renamed
 * {@link HealthByGender}, its contents untouched, and this wide class created for the
 * incoming fields.
 */
@Entity
public class HealthStatistics {

    @Id
    private PanelEntityKey key = new PanelEntityKey(1L);

    //average health
    @Column(name = "health_18_29")
    private double healthScore18to29Avg;

    @Column(name = "health_30_54")
    private double healthScore30to54Avg;

    @Column(name = "health_55_74")
    private double healthScore55to74Avg;

    //population shares disabled
    @Column(name = "pr_disabled_18_29")
    private double demDsbl18to29Share;

    @Column(name = "pr_disabled_30_54")
    private double demDsbl30to54Share;

    @Column(name = "pr_disabled_55_74")
    private double demDsbl55to74Share;


    public double getHealth18to29() {
        return healthScore18to29Avg;
    }

    public void setHealth18to29(double healthScore18to29Avg) {
        this.healthScore18to29Avg = healthScore18to29Avg;
    }

    public double getHealth30to54() {
        return healthScore30to54Avg;
    }

    public void setHealth30to54(double healthScore30to54Avg) {
        this.healthScore30to54Avg = healthScore30to54Avg;
    }

    public double getHealth55to74() {
        return healthScore55to74Avg;
    }

    public void setHealth55to74(double healthScore55to74Avg) {
        this.healthScore55to74Avg = healthScore55to74Avg;
    }

    public double getPrDisabled18to29() {
        return demDsbl18to29Share;
    }

    public void setPrDisabled18to29(double demDsbl18to29Share) {
        this.demDsbl18to29Share = demDsbl18to29Share;
    }

    public double getPrDisabled30to54() {
        return demDsbl30to54Share;
    }

    public void setPrDisabled30to54(double demDsbl30to54Share) {
        this.demDsbl30to54Share = demDsbl30to54Share;
    }

    public double getPrDisabled55to74() {
        return demDsbl55to74Share;
    }

    public void setPrDisabled55to74(double demDsbl55to74Share) {
        this.demDsbl55to74Share = demDsbl55to74Share;
    }

    /** Map the shared age-band aggregates onto this output. */
    public void update(AgeBandAggregates agg) {

        setHealth18to29(agg.healthScore(0));
        setHealth30to54(agg.healthScore(1));
        setHealth55to74(agg.healthScore(2));

        setPrDisabled18to29(agg.prDisabled(0));
        setPrDisabled30to54(agg.prDisabled(1));
        setPrDisabled55to74(agg.prDisabled(2));
    }
}
