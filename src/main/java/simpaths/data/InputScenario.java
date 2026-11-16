package simpaths.data;

import java.io.File;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.function.Predicate;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * An input scenario replaces country input workbooks by the files of the same name in the folder
 * {@code input/<CC>/scenarios/<name>/}. A file that is absent from the folder is read from {@code input/<CC>/}.
 * Every file request is recorded, so that a workbook in the folder that no request matches (a misspelt name)
 * can be reported.
 *
 * <p>Folder and file names are matched exactly, case included: the scenario folder's files are listed once
 * when the scenario is created, and a request matches only an identical name. A wrongly cased workbook is
 * therefore reported as unused on every operating system, rather than read on a case-insensitive file system
 * and ignored on a case-sensitive one. Excel's lock files ({@code ~$<name>.xlsx}, present while a workbook is
 * open) are ignored.</p>
 */
public final class InputScenario {

    /** The rule for a scenario name, the same as in {@code input_processing/scenarios/build_migration_scenario.do}. */
    private static final Pattern NAME = Pattern.compile("^[A-Za-z0-9_][A-Za-z0-9_-]*$");

    /** Prefix of the lock file Excel writes beside an open workbook. */
    private static final String EXCEL_LOCK_PREFIX = "~$";

    private static final InputScenario NONE = new InputScenario(null, null, "", Set.of());

    private final Path countryDir;
    private final Path folder;
    private final String name;
    private final Set<String> filesInFolder;
    private final Set<String> requested = new LinkedHashSet<>();

    private InputScenario(Path countryDir, Path folder, String name, Set<String> filesInFolder) {
        this.countryDir = countryDir;
        this.folder = folder;
        this.name = name;
        this.filesInFolder = filesInFolder;
    }

    /** The scenario that replaces nothing. */
    public static InputScenario none() {
        return NONE;
    }

    /**
     * @param countryDir the country's input folder, {@code input/<CC>}
     * @param name       the scenario's folder name below {@code scenarios/}, surrounding blanks ignored; blank or
     *                   null for no scenario
     */
    public static InputScenario of(Path countryDir, String name) {
        if (name == null || name.isBlank()) {
            return NONE;
        }
        String folderName = name.strip();
        if (!NAME.matcher(folderName).matches()) {
            throw new IllegalArgumentException("Input scenario '" + name + "' is not a folder name. Give only the name "
                    + "of the scenario folder, expected at " + countryDir.resolve("scenarios") + File.separator + "<name>"
                    + "; a name consists of letters, digits, _ and - and does not start with -.");
        }
        Path scenariosDir = countryDir.resolve("scenarios");
        Path expected = scenariosDir.resolve(folderName);
        if (!Files.isDirectory(expected) || !list(scenariosDir, Files::isDirectory).contains(folderName)) {
            throw new IllegalArgumentException("Input scenario '" + folderName + "': folder " + expected
                    + " does not exist (folder names are matched exactly, case included).");
        }
        Set<String> files = list(expected, Files::isRegularFile);
        files.removeIf(n -> n.startsWith(EXCEL_LOCK_PREFIX));
        return new InputScenario(countryDir, expected, folderName, Set.copyOf(files));
    }

    /** Exact names of the entries of {@code dir} that pass {@code filter}. */
    private static Set<String> list(Path dir, Predicate<Path> filter) {
        Set<String> names = new TreeSet<>();
        try (Stream<Path> entries = Files.list(dir)) {
            entries.filter(filter).map(p -> p.getFileName().toString()).forEach(names::add);
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot list folder " + dir, e);
        }
        return names;
    }

    public boolean isActive() {
        return folder != null;
    }

    /** The scenario's name, empty when inactive. */
    public String name() {
        return name;
    }

    /** The scenario's folder, null when inactive. */
    public Path folder() {
        return folder;
    }

    /**
     * Path of the file to read: the scenario folder's file when the folder holds that exact name, else the
     * country folder's. The request is recorded either way. Call only when the scenario is active.
     */
    public String resolve(String fileName) {
        requested.add(fileName);
        return filesInFolder.contains(fileName) ? folder.resolve(fileName).toString() : countryDir.resolve(fileName).toString();
    }

    /** Whether the scenario folder holds the exact name {@code fileName}. */
    public boolean replaces(String fileName) {
        return isActive() && filesInFolder.contains(fileName);
    }

    /** Sorted names of the requested files that the scenario folder holds. */
    public List<String> replacedFiles() {
        List<String> replaced = new ArrayList<>();
        for (String fileName : requested) {
            if (filesInFolder.contains(fileName)) {
                replaced.add(fileName);
            }
        }
        replaced.sort(null);
        return replaced;
    }

    /** One line naming the replaced files, or saying that the scenario replaces no workbook. */
    public String replacementSummary() {
        List<String> replaced = replacedFiles();
        return "Input scenario '" + name + "' replaces "
                + (replaced.isEmpty() ? "no workbook" : String.join(", ", replaced)) + ".";
    }

    /**
     * Sorted names of the .xlsx files in the scenario folder (extension in any case) that no request matched
     * exactly, case included.
     */
    public List<String> unusedWorkbooks() {
        if (!isActive()) {
            return List.of();
        }
        List<String> unused = new ArrayList<>();
        for (String fileName : filesInFolder) {
            if (fileName.toLowerCase(Locale.ROOT).endsWith(".xlsx") && !requested.contains(fileName)) {
                unused.add(fileName);
            }
        }
        unused.sort(null);
        return unused;
    }

    /** Fails when the scenario's population workbook covers other years than the baseline's. Ranges are {first, last}. */
    public static void requireSamePopulationYears(String scenarioName, int[] scenarioYears, int[] baselineYears) {
        if (scenarioYears[0] != baselineYears[0] || scenarioYears[1] != baselineYears[1]) {
            throw new IllegalStateException("Input scenario '" + scenarioName + "': align_popProjections.xlsx covers "
                    + scenarioYears[0] + "-" + scenarioYears[1] + ", the baseline workbook covers "
                    + baselineYears[0] + "-" + baselineYears[1] + ". A scenario workbook must cover the same years.");
        }
    }

    /**
     * Fails when the scenario's population workbook ends at another age than the baseline's. The last age
     * bounds the ages of the starting population, which enters the cached starting population.
     */
    public static void requireSamePopulationMaxAge(String scenarioName, int scenarioMaxAge, int baselineMaxAge) {
        if (scenarioMaxAge != baselineMaxAge) {
            throw new IllegalStateException("Input scenario '" + scenarioName + "': align_popProjections.xlsx ends at age "
                    + scenarioMaxAge + ", the baseline workbook at age " + baselineMaxAge
                    + ". A scenario workbook must cover the same ages: the last age bounds the cached starting population (table Processed).");
        }
    }

    /** Fails when the scenario's start-year population cells differ from the baseline's. */
    public static void requirePopulationStartYearUnchanged(String scenarioName, int startYear,
                                                           Map<String, Double> scenario, Map<String, Double> baseline) {
        List<String> differing = differingCells(scenario, baseline);
        if (!differing.isEmpty()) {
            throw new IllegalStateException("Input scenario '" + scenarioName + "' changes the population of the start year "
                    + startYear + " in align_popProjections.xlsx (first differing cells: " + firstFive(differing)
                    + "). A scenario may not change the start year's population: the cached starting population (table Processed) was prepared against the baseline workbook.");
        }
    }

    /** Fails when the cells that enter the cached starting population differ between scenario and baseline workbook. */
    public static void requireCachedInputsUnchanged(String scenarioName, String what, String workbook,
                                                    Map<String, Double> scenario, Map<String, Double> baseline) {
        List<String> differing = differingCells(scenario, baseline);
        if (!differing.isEmpty()) {
            throw new IllegalStateException("Input scenario '" + scenarioName + "' changes " + what + " in " + workbook
                    + " (first differing cells: " + firstFive(differing)
                    + "). A scenario may not change inputs of the cached starting population (table Processed), which was prepared against the baseline workbook.");
        }
    }

    /** Fails when the scenario folder holds workbooks that no input file name matches. */
    public static void requireNoUnusedWorkbooks(String scenarioName, List<String> unused, String countryDir) {
        if (!unused.isEmpty()) {
            throw new IllegalStateException("Input scenario '" + scenarioName + "' holds workbooks no input file name matches: "
                    + String.join(", ", unused) + ". Check their spelling, case included, against the files in " + countryDir + ".");
        }
    }

    /** The uprating series enter the cached starting population only when the start year is past the last available population. */
    public static boolean timeSeriesEntersCachedPopulation(int startYear, int maxStartYear) {
        return startYear > maxStartYear;
    }

    private static String firstFive(List<String> keys) {
        return String.join(", ", keys.subList(0, Math.min(5, keys.size())));
    }

    /** Sorted keys whose values differ between the two maps, or that exist in only one of them. */
    public static List<String> differingCells(Map<String, Double> scenario, Map<String, Double> baseline) {
        Set<String> keys = new TreeSet<>(scenario.keySet());
        keys.addAll(baseline.keySet());
        List<String> differing = new ArrayList<>();
        for (String key : keys) {
            Double s = scenario.get(key);
            Double b = baseline.get(key);
            if (s == null || b == null || s.doubleValue() != b.doubleValue()) {
                differing.add(key);
            }
        }
        return differing;
    }
}
