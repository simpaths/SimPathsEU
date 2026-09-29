package simpaths.data.statistics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;

import microsim.data.db.PanelEntityKey;

/**
 * Income and wealth statistics. One row per simulated year, exported to
 * {@code WealthIncomeStatistics.csv}. Records:
 *   - national Gini coefficients, income percentiles, median equivalised disposable
 *     income and the median security index, all set by {@code SimPathsCollector}
 *   - by age band (18-29, 30-54, 55-74): labour, investment and pension income,
 *     investment losses, disposable income gross of losses, and liquid wealth
 *
 * <p>Formerly {@code Statistics}, exported as {@code Statistics1.csv} — the trailing digit
 * was the entity id, not part of the name. The age-band columns came out of the omnibus
 * {@code Statistics2} (see {@link DemographicStatistics}) and are fed from the shared
 * {@link AgeBandAggregates}.
 *
 * <p>The former {@code statYDisp*Avg} (disposable income) and {@code x*Avg} (expenditure)
 * columns are not carried over: they were calibration residuals rather than levels (see
 * {@link DemographicStatistics}). {@code statYDispGrossOfLosses*Avg} below is a level and
 * survives.
 */
@Entity
public class WealthIncomeStatistics {

	@Id
	private PanelEntityKey key = new PanelEntityKey(1L);

	@Column(name = "Gini_coefficient_individual_market_income_nationally")
	private double statYMktNatGini;

	@Column(name = "Gini_coefficient_equivalised_household_disposable_income_nationally")
	private double statYHhDispEquivNatGini;

	@Column(name = "Median_equivalised_household_disposable_income")
	private double yHhDispEquivP50;
	
	//Percentiles of ydses:
	@Column(name = "Ydses_p20")
	private double yHhQuintilesC5P20;
	
	@Column(name = "Ydses_p40")
	private double yHhQuintilesC5P40;
	
	@Column(name = "Ydses_p60")
	private double yHhQuintilesC5P60;
	
	@Column(name = "Ydses_p80")
	private double yHhQuintilesC5P80;

	//Percentiles of gross labour income:
	@Column(name = "Gross_Labour_Income_p20")
	private double yLabP20;

	@Column(name = "Gross_Labour_Income_p40")
	private double yLabP40;

	@Column(name = "Gross_Labour_Income_p60")
	private double yLabP60;

	@Column(name = "Gross_Labour_Income_p80")
	private double yLabP80;

	//Equivalised disposable income
	@Column(name = "EDI_p50")
	private double demEdiP50;

	//Percentiles of SIndex:
	@Column(name = "SIndex_p50")
	private double statSIndexP50;

	//employment income: weekly earnings per worker, not equivalised (unlike every other
	//income column here, which is monthly, equivalised and per capita)
	@Column(name = "labourIncome_weekly_perWorker_18_29")
	private double statYLabWeeklyPerWorker18to29Avg;

	@Column(name = "labourIncome_weekly_perWorker_30_54")
	private double statYLabWeeklyPerWorker30to54Avg;

	@Column(name = "labourIncome_weekly_perWorker_55_74")
	private double statYLabWeeklyPerWorker55to74Avg;

	//investment income
	@Column(name = "investmentIncome_18_29")
	private double statYInvest18to29Avg;

	@Column(name = "investmentIncome_30_54")
	private double statYInvest30to54Avg;

	@Column(name = "investmentIncome_55_74")
	private double statYInvest55to74Avg;

	//pension income
	@Column(name = "pensionIncome_18_29")
	private double statYPens18to29Avg;

	@Column(name = "pensionIncome_30_54")
	private double statYPens30to54Avg;

	@Column(name = "pensionIncome_55_74")
	private double statYPens55to74Avg;

	//investment losses
	@Column(name = "investmentLosses_18_29")
	private double statInvestLoss18to29Avg;

	@Column(name = "investmentLosses_30_54")
	private double statInvestLoss30to54Avg;

	@Column(name = "investmentLosses_55_74")
	private double statInvestLoss55to74Avg;

	//disposable income gross of investment losses
	@Column(name = "dispInc_grossLosses_18_29")
	private double statYDispGrossOfLosses18to29Avg;

	@Column(name = "dispInc_grossLosses_30_54")
	private double statYDispGrossOfLosses30to54Avg;

	@Column(name = "dispInc_grossLosses_55_74")
	private double statYDispGrossOfLosses55to74Avg;

	//wealth
	@Column(name = "wealth_18_29")
	private double wealth18to29Avg;

	@Column(name = "wealth_30_54")
	private double wealth30to54Avg;

	@Column(name = "wealth_55_74")
	private double wealth55to74Avg;

	////	Risk-of-poverty threshold is set at 60% of the national median equivalised household disposable income.
//	@Column(name = "Risk_of_poverty_threshold")
//	private double riskOfPovertyThreshold;
	
	public void setGiniPersonalGrossEarningsNational(double statYMktNatGini) {
		this.statYMktNatGini = statYMktNatGini;
	}
	
	public void setGiniEquivalisedHouseholdDisposableIncomeNational(double statYHhDispEquivNatGini) {
		this.statYHhDispEquivNatGini = statYHhDispEquivNatGini;
	}

	public double getMedianEquivalisedHouseholdDisposableIncome() {
		return yHhDispEquivP50;
	}

	public void setMedianEquivalisedHouseholdDisposableIncome(double yHhDispEquivP50) {
		this.yHhDispEquivP50 = yHhDispEquivP50;
	}
	
	public double getYdses_p20() {
		return yHhQuintilesC5P20;
	}

	public void setYdses_p20(double yHhQuintilesC5P20) {
		this.yHhQuintilesC5P20 = yHhQuintilesC5P20;
	}

	public double getYdses_p40() {
		return yHhQuintilesC5P40;
	}

	public void setYdses_p40(double yHhQuintilesC5P40) {
		this.yHhQuintilesC5P40 = yHhQuintilesC5P40;
	}

	public double getYdses_p60() {
		return yHhQuintilesC5P60;
	}

	public void setYdses_p60(double yHhQuintilesC5P60) {
		this.yHhQuintilesC5P60 = yHhQuintilesC5P60;
	}

	public double getYdses_p80() {
		return yHhQuintilesC5P80;
	}

	public void setYdses_p80(double yHhQuintilesC5P80) {
		this.yHhQuintilesC5P80 = yHhQuintilesC5P80;
	}

	public double getsIndex_p50() {
		return statSIndexP50;
	}

	public void setsIndex_p50(double statSIndexP50) {
		this.statSIndexP50 = statSIndexP50;
	}

	public double getGrossLabourIncome_p20() {
		return yLabP20;
	}

	public void setGrossLabourIncome_p20(double yLabP20) {
		this.yLabP20 = yLabP20;
	}

	public double getGrossLabourIncome_p40() {
		return yLabP40;
	}

	public void setGrossLabourIncome_p40(double yLabP40) {
		this.yLabP40 = yLabP40;
	}

	public double getGrossLabourIncome_p60() {
		return yLabP60;
	}

	public void setGrossLabourIncome_p60(double yLabP60) {
		this.yLabP60 = yLabP60;
	}

	public double getGrossLabourIncome_p80() {
		return yLabP80;
	}

	public void setGrossLabourIncome_p80(double yLabP80) {
		this.yLabP80 = yLabP80;
	}

	public double getEdi_p50() {
		return demEdiP50;
	}

	public void setEdi_p50(double demEdiP50) {
		this.demEdiP50 = demEdiP50;
	}

	public double getLabourIncomeWeeklyPerWorker18to29() {
		return statYLabWeeklyPerWorker18to29Avg;
	}

	public void setLabourIncomeWeeklyPerWorker18to29(double statYLabWeeklyPerWorker18to29Avg) {
		this.statYLabWeeklyPerWorker18to29Avg = statYLabWeeklyPerWorker18to29Avg;
	}

	public double getLabourIncomeWeeklyPerWorker30to54() {
		return statYLabWeeklyPerWorker30to54Avg;
	}

	public void setLabourIncomeWeeklyPerWorker30to54(double statYLabWeeklyPerWorker30to54Avg) {
		this.statYLabWeeklyPerWorker30to54Avg = statYLabWeeklyPerWorker30to54Avg;
	}

	public double getLabourIncomeWeeklyPerWorker55to74() {
		return statYLabWeeklyPerWorker55to74Avg;
	}

	public void setLabourIncomeWeeklyPerWorker55to74(double statYLabWeeklyPerWorker55to74Avg) {
		this.statYLabWeeklyPerWorker55to74Avg = statYLabWeeklyPerWorker55to74Avg;
	}

	public double getInvestmentIncome18to29() {
		return statYInvest18to29Avg;
	}

	public void setInvestmentIncome18to29(double statYInvest18to29Avg) {
		this.statYInvest18to29Avg = statYInvest18to29Avg;
	}

	public double getInvestmentIncome30to54() {
		return statYInvest30to54Avg;
	}

	public void setInvestmentIncome30to54(double statYInvest30to54Avg) {
		this.statYInvest30to54Avg = statYInvest30to54Avg;
	}

	public double getInvestmentIncome55to74() {
		return statYInvest55to74Avg;
	}

	public void setInvestmentIncome55to74(double statYInvest55to74Avg) {
		this.statYInvest55to74Avg = statYInvest55to74Avg;
	}

	public double getPensionIncome18to29() {
		return statYPens18to29Avg;
	}

	public void setPensionIncome18to29(double statYPens18to29Avg) {
		this.statYPens18to29Avg = statYPens18to29Avg;
	}

	public double getPensionIncome30to54() {
		return statYPens30to54Avg;
	}

	public void setPensionIncome30to54(double statYPens30to54Avg) {
		this.statYPens30to54Avg = statYPens30to54Avg;
	}

	public double getPensionIncome55to74() {
		return statYPens55to74Avg;
	}

	public void setPensionIncome55to74(double statYPens55to74Avg) {
		this.statYPens55to74Avg = statYPens55to74Avg;
	}

	public double getInvestmentLosses18to29() {
		return statInvestLoss18to29Avg;
	}

	public void setInvestmentLosses18to29(double statInvestLoss18to29Avg) {
		this.statInvestLoss18to29Avg = statInvestLoss18to29Avg;
	}

	public double getInvestmentLosses30to54() {
		return statInvestLoss30to54Avg;
	}

	public void setInvestmentLosses30to54(double statInvestLoss30to54Avg) {
		this.statInvestLoss30to54Avg = statInvestLoss30to54Avg;
	}

	public double getInvestmentLosses55to74() {
		return statInvestLoss55to74Avg;
	}

	public void setInvestmentLosses55to74(double statInvestLoss55to74Avg) {
		this.statInvestLoss55to74Avg = statInvestLoss55to74Avg;
	}

	public double getDispIncomeGrossOfLosses18to29() {
		return statYDispGrossOfLosses18to29Avg;
	}

	public void setDispIncomeGrossOfLosses18to29(double statYDispGrossOfLosses18to29Avg) {
		this.statYDispGrossOfLosses18to29Avg = statYDispGrossOfLosses18to29Avg;
	}

	public double getDispIncomeGrossOfLosses30to54() {
		return statYDispGrossOfLosses30to54Avg;
	}

	public void setDispIncomeGrossOfLosses30to54(double statYDispGrossOfLosses30to54Avg) {
		this.statYDispGrossOfLosses30to54Avg = statYDispGrossOfLosses30to54Avg;
	}

	public double getDispIncomeGrossOfLosses55to74() {
		return statYDispGrossOfLosses55to74Avg;
	}

	public void setDispIncomeGrossOfLosses55to74(double statYDispGrossOfLosses55to74Avg) {
		this.statYDispGrossOfLosses55to74Avg = statYDispGrossOfLosses55to74Avg;
	}

	public double getWealth18to29() {
		return wealth18to29Avg;
	}

	public void setWealth18to29(double wealth18to29Avg) {
		this.wealth18to29Avg = wealth18to29Avg;
	}

	public double getWealth30to54() {
		return wealth30to54Avg;
	}

	public void setWealth30to54(double wealth30to54Avg) {
		this.wealth30to54Avg = wealth30to54Avg;
	}

	public double getWealth55to74() {
		return wealth55to74Avg;
	}

	public void setWealth55to74(double wealth55to74Avg) {
		this.wealth55to74Avg = wealth55to74Avg;
	}

	/**
	 * Map the shared age-band aggregates onto this output. The Gini, percentile, median
	 * EDI and S-Index fields are not touched here - they are set by SimPathsCollector as
	 * its own calculation events fire.
	 */
	public void update(AgeBandAggregates agg) {

		setLabourIncomeWeeklyPerWorker18to29(agg.labourIncomeWeeklyPerWorker(0));
		setLabourIncomeWeeklyPerWorker30to54(agg.labourIncomeWeeklyPerWorker(1));
		setLabourIncomeWeeklyPerWorker55to74(agg.labourIncomeWeeklyPerWorker(2));

		setInvestmentIncome18to29(agg.investmentIncome(0));
		setInvestmentIncome30to54(agg.investmentIncome(1));
		setInvestmentIncome55to74(agg.investmentIncome(2));

		setPensionIncome18to29(agg.pensionIncome(0));
		setPensionIncome30to54(agg.pensionIncome(1));
		setPensionIncome55to74(agg.pensionIncome(2));

		setInvestmentLosses18to29(agg.investmentLosses(0));
		setInvestmentLosses30to54(agg.investmentLosses(1));
		setInvestmentLosses55to74(agg.investmentLosses(2));

		setDispIncomeGrossOfLosses18to29(agg.dispIncomeGrossOfLosses(0));
		setDispIncomeGrossOfLosses30to54(agg.dispIncomeGrossOfLosses(1));
		setDispIncomeGrossOfLosses55to74(agg.dispIncomeGrossOfLosses(2));

		setWealth18to29(agg.wealth(0));
		setWealth30to54(agg.wealth(1));
		setWealth55to74(agg.wealth(2));
	}

//	public double getRiskOfPovertyThreshold() {
//		return riskOfPovertyThreshold;
//	}
//
//	public void setRiskOfPovertyThreshold(double riskOfPovertyThreshold) {
//		this.riskOfPovertyThreshold = riskOfPovertyThreshold;
//	}

}
