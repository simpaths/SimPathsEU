// define package
package simpaths.experiment;

// import Java packages
import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import microsim.engine.SimulationEngine;
import simpaths.data.Parameters;
import simpaths.model.SimPathsModel;

/**
 *
 * WRITES A README ALONGSIDE THE CSV OUTPUT OF A SIMULATION RUN
 *
 * The README records the configuration the run was executed under - population size,
 * simulated years, alignment switches, whether regression coefficients were bootstrapped -
 * together with a description of each CSV file written beside it.
 *
 * Output folders outlive the configuration that produced them, so a run whose settings are
 * not recorded next to its results cannot be interpreted with confidence later on.
 *
 */
public class OutputReadme {

    private static final Logger log = LogManager.getLogger(OutputReadme.class);

    private static final DateTimeFormatter TIMESTAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    // Set once the README has been written. A multi-run builds a fresh experiment - with a
    // fresh timestamped output folder - for every run, but ExportCSV fixes its directory
    // once per JVM (a static final initialised on first use), so every run's CSVs land in
    // the first run's folder. Writing only once keeps a single README beside them rather
    // than one per run, each in an otherwise empty folder.
    private static boolean written = false;

    private OutputReadme() {}

    /**
     *
     * WRITE README.md INTO THE CSV OUTPUT DIRECTORY
     *
     * Only the first call in a JVM writes anything; see {@link #written}.
     * Failure to write the README must never interrupt a simulation, so all errors are
     * logged rather than propagated.
     *
     * @param collector the collector holding the output toggles for this run
     * @param model the simulation manager holding the run configuration
     *
     */
    public static synchronized void write(SimPathsCollector collector, SimPathsModel model) {

        if (written)
            return;
        Path directory = csvDirectory();
        if (directory != null) {
            write(collector, model, directory);
            written = true;
        }
    }

    /**
     *
     * WRITE README.md INTO A GIVEN DIRECTORY
     * @param collector the collector holding the output toggles for this run
     * @param model the simulation manager holding the run configuration
     * @param directory the directory to write into, created if it does not exist
     *
     */
    static void write(SimPathsCollector collector, SimPathsModel model, Path directory) {

        try {
            Files.createDirectories(directory);

            try (PrintWriter out = new PrintWriter(Files.newBufferedWriter(directory.resolve("README.md"),
                    StandardCharsets.UTF_8))) {
                writeHeader(out, model);
                writeRunConfiguration(out, model);
                writeModelOptions(out, model);
                writeFileDescriptions(out, collector);
                writeConventions(out);
            }
        } catch (IOException | RuntimeException e) {
            log.warn("Could not write output README: " + e.getMessage());
        }
    }

    private static Path csvDirectory() {

        // This is the expression ExportCSV resolves its own output directory from -
        // getOutputFolder() + separator + "csv" - so the README lands beside the data.
        // ExportCSV.directory itself is package-private, and reading it would force that
        // class to initialise before the experiment is set up, so it is recomputed here.
        try {
            String outputFolder = SimulationEngine.getInstance().getCurrentExperiment().getOutputFolder();
            if (outputFolder == null)
                return null;
            return new File(outputFolder, "csv").toPath();
        } catch (RuntimeException e) {
            log.warn("Could not resolve the output folder for the README: " + e.getMessage());
            return null;
        }
    }

    private static void writeHeader(PrintWriter out, SimPathsModel model) {

        out.println("# SimPaths simulation output");
        out.println();
        out.println("Country: **" + model.getCountry() + "**  ");
        out.println("Written: " + LocalDateTime.now().format(TIMESTAMP));
        out.println();
        out.println("This folder holds the CSV output of a simulation experiment. The settings below");
        out.println("are those it was executed under; they are recorded here because output folders");
        out.println("are kept long after the configuration that produced them has moved on.");
        out.println();
    }

    private static void writeRunConfiguration(PrintWriter out, SimPathsModel model) {

        boolean multiRun = SimPathsMultiRun.isMultiRunMode() && SimPathsMultiRun.getMaxNumberOfRuns() > 1;
        String runsPlanned = SimPathsMultiRun.isMultiRunMode()
                ? String.valueOf(SimPathsMultiRun.getMaxNumberOfRuns())
                : "1 (single run)";

        // The README is written by the first run, so the seed held by the model is the first
        // run's. SimPathsMultiRun.iterateParameters() adds one to it before each later run
        // unless randomSeedInnov is switched off, so run k uses first + k - 1.
        String seed;
        if (!Boolean.TRUE.equals(model.getFixRandomSeed())) {
            seed = "not fixed";
        } else {
            long first = model.getRandomSeedIfFixed();
            if (!multiRun)
                seed = String.valueOf(first);
            else if (SimPathsMultiRun.isRandomSeedInnov())
                seed = first + " to " + (first + SimPathsMultiRun.getMaxNumberOfRuns() - 1)
                        + " (run *k* uses " + first + " + *k* - 1)";
            else
                seed = first + " (the same for every run)";
        }

        out.println("## Run configuration");
        out.println();
        out.println("| Setting | Value |");
        out.println("|---|---|");
        out.println("| Runs in this experiment | " + runsPlanned + " |");
        out.println("| Population size | " + model.getPopSize() + " |");
        out.println("| Start year | " + model.getStartYear() + " |");
        out.println("| End year | " + model.getEndYear() + " |");
        out.println((multiRun ? "| Random seeds | " : "| Random seed | ") + seed + " |");
        out.println("| Base price year | " + Parameters.BASE_PRICE_YEAR + " |");
        out.println("| Training data | " + (Parameters.trainingFlag ? "yes" : "no") + " |");
        out.println();
        if (Parameters.trainingFlag) {
            out.println("**This run used the training-data subset.** Results are for development only and");
            out.println("should not be interpreted as estimates for this country.");
            out.println();
        }
    }

    private static void writeModelOptions(PrintWriter out, SimPathsModel model) {

        out.println("## Model options");
        out.println();
        out.println("| Option | State |");
        out.println("|---|---|");
        out.println("| Bootstrap all regression coefficients | " + onOff(Parameters.bootstrapAll) + " |");
        out.println("| Intertemporal optimisations | " + onOff(model.getEnableIntertemporalOptimisations()) + " |");
        out.println("| Project mortality | " + onOff(model.getProjectMortality()) + " |");
        out.println("| Alignment: population | " + onOff(model.isAlignPopulation()) + " |");
        out.println("| Alignment: fertility | " + onOff(model.isAlignFertility()) + " |");
        out.println("| Alignment: cohabitation | " + onOff(model.isAlignCohabitation()) + " |");
        out.println("| Alignment: in school | " + onOff(model.isAlignInSchool()) + " |");
        out.println("| Alignment: employment | " + onOff(model.isAlignEmployment()) + " |");
        out.println("| Alignment: retirement | " + onOff(model.isAlignRetirement()) + " |");
        out.println("| Alignment: disability | " + onOff(model.isAlignDisability()) + " |");
        out.println("| Alignment: education | " + onOff(model.isAlignEducation()) + " |");
        out.println();
        out.println("Diagnostics for the alignment routines that ran are in `AlignmentStatistics.csv`,");
        out.println("which reports the adjustment factor, the simulated share and the target share each year.");
        out.println();
    }

    private static void writeFileDescriptions(PrintWriter out, SimPathsCollector collector) {

        out.println("## Files in this folder");
        out.println();
        out.println("Age bands used by the annual statistics are 18-29, 30-54 and 55-74.");
        out.println();

        describe(out, collector.isPersistWealthIncomeStatistics(), "WealthIncomeStatistics.csv", "one row per year",
                "Income and wealth. Gini coefficients for market and equivalised disposable income, "
                        + "income percentiles, median equivalised disposable income and the S-Index, plus "
                        + "labour, investment and pension income, investment losses, disposable income gross "
                        + "of losses, and wealth by age band.");

        describe(out, collector.isPersistDemographicStatistics(), "DemographicStatistics.csv", "one row per year",
                "Demographics by age band: share cohabiting, average dependent children, and population "
                        + "counts. The population counts are the denominator for the age-band statistics "
                        + "reported in the other files.");

        describe(out, collector.isPersistHealthStatistics(), "HealthStatistics.csv", "one row per year",
                "Population health by age band: average self-rated health and the share reporting a "
                        + "long-term disability.");

        describe(out, collector.isPersistLabourStatistics(), "LabourStatistics.csv", "one row per year",
                "Labour market outcomes. Employment and unemployment shares for ages 16-64 and the "
                        + "transition rates between them, plus full-time and part-time shares by age band.");

        describe(out, collector.isPersistAlignmentStatistics(), "AlignmentStatistics.csv", "one row per year",
                "Alignment diagnostics: adjustment factors together with the simulated and target shares "
                        + "for each aligned process.");

        describe(out, collector.isPersistHealthByGender(), "HealthByGender.csv", "three rows per year",
                "Self-rated health and disability for ages 16-64: the share in each self-rated health "
                        + "category (poor, fair, good, very good, excellent), the share long-term sick or "
                        + "disabled, and the observation counts each is based on. Written once per gender "
                        + "group each year - Total, Male and Female - identified by the `demSex` column.");

        describe(out, collector.isPersistPersons(), "Person.csv", "one row per person per year",
                "Individual-level microdata for the whole simulated population.");

        describe(out, collector.isPersistBenefitUnits(), "BenefitUnit.csv", "one row per benefit unit per year",
                "Benefit-unit-level microdata, the unit at which taxes and benefits are assessed.");

        describe(out, collector.isPersistHouseholds(), "Household.csv", "one row per household per year",
                "Household-level microdata.");

        out.println();
    }

    private static void describe(PrintWriter out, boolean enabled, String fileName, String shape, String contents) {

        if (!enabled)
            return;
        out.println("### `" + fileName + "`");
        out.println();
        out.println("*" + shape + "*");
        out.println();
        out.println(contents);
        out.println();
    }

    private static void writeConventions(PrintWriter out) {

        out.println("## Reading the files");
        out.println();
        out.println("- Every file opens with `run`, `time` and an `id_<name>` column. `run` identifies the");
        out.println("  simulation run - where several runs share an output folder they all appear in the same");
        out.println("  file - `time` is the simulated year, and the id column is a constant for the annual");
        out.println("  statistics.");
        out.println("- Remaining columns are ordered alphabetically by variable name, not by topic.");
        out.println("- Financial variables are in real prices of the base price year given above,");
        out.println("  and are monthly and equivalised unless the variable name says otherwise.");
        out.println("- Variables carrying `WeeklyPerWorker` are weekly, averaged over workers rather than");
        out.println("  over the population, and are not equivalised.");
        out.println();
    }

    private static String onOff(boolean flag) {
        return flag ? "on" : "off";
    }
}
