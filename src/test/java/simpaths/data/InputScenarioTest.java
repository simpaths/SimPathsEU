package simpaths.data;

import microsim.data.MultiKeyCoefficientMap;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class InputScenarioTest {

    @TempDir
    Path countryDir;

    private Path scenarioFolder() throws IOException {
        return Files.createDirectories(countryDir.resolve("scenarios").resolve("s1"));
    }

    @Test
    void blankNameIsInactive() {
        assertFalse(InputScenario.of(countryDir, "").isActive());
        assertFalse(InputScenario.of(countryDir, null).isActive());
    }

    @Test
    void missingFolderFailsNamingIt() {
        var e = assertThrows(IllegalArgumentException.class, () -> InputScenario.of(countryDir, "nope"));
        assertTrue(e.getMessage().contains(countryDir.resolve("scenarios").resolve("nope").toString()));
    }

    @Test
    void nameWithPathSeparatorIsRejected() throws IOException {
        scenarioFolder();
        for (String bad : new String[]{"scenarios/s1", "..\\s1", "s1/", "../s1", ".", "..", "a:b", "-s1", "s 1"}) {
            var e = assertThrows(IllegalArgumentException.class, () -> InputScenario.of(countryDir, bad), bad);
            assertTrue(e.getMessage().contains("is not a folder name"), bad + ": " + e.getMessage());
            assertTrue(e.getMessage().contains(countryDir.resolve("scenarios") + File.separator + "<name>"), e.getMessage());
            assertTrue(e.getMessage().contains("letters, digits, _ and -"), e.getMessage());
        }
    }

    @Test
    void surroundingBlanksAreIgnored() throws IOException {
        Path folder = scenarioFolder();
        var s = InputScenario.of(countryDir, " s1 ");
        assertTrue(s.isActive());
        assertEquals("s1", s.name());
        assertEquals(folder, s.folder());
    }

    @Test
    void folderNameIsMatchedExactly() throws IOException {
        Files.createDirectories(countryDir.resolve("scenarios").resolve("Mig"));
        var e = assertThrows(IllegalArgumentException.class, () -> InputScenario.of(countryDir, "mig"));
        assertTrue(e.getMessage().contains("does not exist"), e.getMessage());
        assertTrue(InputScenario.of(countryDir, "Mig").isActive());
    }

    @Test
    void wronglyCasedWorkbookIsReportedAndNotRead() throws IOException {
        Path folder = scenarioFolder();
        Files.writeString(folder.resolve("Align_popProjections.xlsx"), "x");
        var s = InputScenario.of(countryDir, "s1");
        assertEquals(countryDir.resolve("align_popProjections.xlsx").toString(), s.resolve("align_popProjections.xlsx"));
        assertFalse(s.replaces("align_popProjections.xlsx"));
        assertEquals(List.of(), s.replacedFiles());
        assertEquals(List.of("Align_popProjections.xlsx"), s.unusedWorkbooks());
        assertThrows(IllegalStateException.class,
                () -> InputScenario.requireNoUnusedWorkbooks(s.name(), s.unusedWorkbooks(), countryDir.toString()));
    }

    @Test
    void wronglyCasedExtensionCountsAsAnUnusedWorkbook() throws IOException {
        Path folder = scenarioFolder();
        Files.writeString(folder.resolve("align_popProjections.XLSX"), "x");
        var s = InputScenario.of(countryDir, "s1");
        assertEquals(countryDir.resolve("align_popProjections.xlsx").toString(), s.resolve("align_popProjections.xlsx"));
        assertEquals(List.of("align_popProjections.XLSX"), s.unusedWorkbooks());
    }

    @Test
    void excelLockFileIsIgnored() throws IOException {
        Path folder = scenarioFolder();
        Files.writeString(folder.resolve("align_popProjections.xlsx"), "x");
        Files.writeString(folder.resolve("~$align_popProjections.xlsx"), "x");
        var s = InputScenario.of(countryDir, "s1");
        s.resolve("align_popProjections.xlsx");
        assertEquals(List.of(), s.unusedWorkbooks());
        assertEquals(List.of("align_popProjections.xlsx"), s.replacedFiles());
        assertFalse(s.replaces("~$align_popProjections.xlsx"));
    }

    @Test
    void replacementSummaryNamesTheFilesOrSaysNoWorkbook() throws IOException {
        Path folder = scenarioFolder();
        Files.writeString(folder.resolve("ramsey_migration.csv"), "x");
        var none = InputScenario.of(countryDir, "s1");
        none.resolve("parameters.xlsx");
        assertEquals("Input scenario 's1' replaces no workbook.", none.replacementSummary());
        Files.writeString(folder.resolve("align_popProjections.xlsx"), "x");
        var one = InputScenario.of(countryDir, "s1");
        one.resolve("parameters.xlsx");
        one.resolve("align_popProjections.xlsx");
        assertEquals("Input scenario 's1' replaces align_popProjections.xlsx.", one.replacementSummary());
    }

    @Test
    void populationMaxAgeMismatchNamesBothAges() {
        var e = assertThrows(IllegalStateException.class,
                () -> InputScenario.requireSamePopulationMaxAge("m", 90, 100));
        assertTrue(e.getMessage().contains("ends at age 90"), e.getMessage());
        assertTrue(e.getMessage().contains("baseline workbook at age 100"), e.getMessage());
        assertDoesNotThrow(() -> InputScenario.requireSamePopulationMaxAge("m", 100, 100));
    }

    @SuppressWarnings("unchecked")
    @Test
    void populationMaxAgeIsTheLastAgeOfWomenInTheProbeRegionAndYear() {
        var map = new MultiKeyCoefficientMap(new String[]{"gender", "region", "age"}, new String[]{"2011", "2012"});
        for (int age = 0; age <= 90; age++) map.put("Female", "PL2", age, new Object[]{1.0, 1.0});
        map.put("Female", "PL2", 91, new Object[]{null, 1.0});    // age 91 only in 2012
        for (int age = 0; age <= 100; age++) map.put("Male", "PL2", age, new Object[]{1.0, 1.0});
        for (int age = 0; age <= 100; age++) map.put("Female", "PL4", age, new Object[]{1.0, 1.0});
        assertEquals(90, Parameters.populationMaxAge(map, "PL2", 2011));
        assertEquals(91, Parameters.populationMaxAge(map, "PL2", 2012));
        assertEquals(100, Parameters.populationMaxAge(map, "PL4", 2011));
    }

    @Test
    void fileInFolderReplacesAndOthersFallBack() throws IOException {
        Path folder = scenarioFolder();
        Files.writeString(folder.resolve("align_popProjections.xlsx"), "x");
        var s = InputScenario.of(countryDir, "s1");
        assertEquals(folder.resolve("align_popProjections.xlsx").toString(), s.resolve("align_popProjections.xlsx"));
        assertEquals(countryDir.resolve("parameters.xlsx").toString(), s.resolve("parameters.xlsx"));
        assertEquals(List.of("align_popProjections.xlsx"), s.replacedFiles());
        assertTrue(s.replaces("align_popProjections.xlsx"));
        assertFalse(s.replaces("parameters.xlsx"));
    }

    @Test
    void unrequestedWorkbookIsReportedButOtherFilesAreNot() throws IOException {
        Path folder = scenarioFolder();
        Files.writeString(folder.resolve("align_popProjections.xlsx"), "x");
        Files.writeString(folder.resolve("align_popProjection.xlsx"), "x");
        Files.writeString(folder.resolve("README.md"), "x");
        Files.writeString(folder.resolve("ramsey_migration.csv"), "x");
        var s = InputScenario.of(countryDir, "s1");
        s.resolve("align_popProjections.xlsx");
        assertEquals(List.of("align_popProjection.xlsx"), s.unusedWorkbooks());
    }

    @Test
    void populationYearRangeMismatchNamesBothRanges() {
        var e = assertThrows(IllegalStateException.class,
                () -> InputScenario.requireSamePopulationYears("m", new int[]{2011, 2050}, new int[]{2011, 2060}));
        assertTrue(e.getMessage().contains("2011-2050"));
        assertTrue(e.getMessage().contains("2011-2060"));
        assertDoesNotThrow(() -> InputScenario.requireSamePopulationYears("m", new int[]{2011, 2060}, new int[]{2011, 2060}));
    }

    @Test
    void populationStartYearChangeIsRefusedWithTheAgreedMessage() {
        var base = Map.of("Female|PL2|20", 10.0, "Male|PL2|20", 11.0);
        var scen = Map.of("Female|PL2|20", 10.0, "Male|PL2|20", 12.0);
        var e = assertThrows(IllegalStateException.class,
                () -> InputScenario.requirePopulationStartYearUnchanged("m", 2023, scen, base));
        assertTrue(e.getMessage().contains("changes the population of the start year 2023"));
        assertTrue(e.getMessage().contains("Male|PL2|20"));
        assertDoesNotThrow(() -> InputScenario.requirePopulationStartYearUnchanged("m", 2023, base, base));
    }

    @Test
    void cachedInputGuardRefusesDifferingValuesAndPassesEqualOnes() {
        var base = Map.of("AGE_TO_BECOME_RESPONSIBLE", 18.0, "MAX_START_YEAR", 2023.0);
        var changed = Map.of("AGE_TO_BECOME_RESPONSIBLE", 16.0, "MAX_START_YEAR", 2023.0);
        var missing = Map.of("AGE_TO_BECOME_RESPONSIBLE", 18.0);
        var e = assertThrows(IllegalStateException.class,
                () -> InputScenario.requireCachedInputsUnchanged("m", "parameters", "parameters.xlsx", changed, base));
        assertTrue(e.getMessage().contains("changes parameters in parameters.xlsx (first differing cells: AGE_TO_BECOME_RESPONSIBLE)"));
        assertTrue(e.getMessage().contains("cached starting population (table Processed)"));
        assertThrows(IllegalStateException.class,
                () -> InputScenario.requireCachedInputsUnchanged("m", "parameters", "parameters.xlsx", missing, base));
        assertDoesNotThrow(() -> InputScenario.requireCachedInputsUnchanged("m", "parameters", "parameters.xlsx", base, base));
    }

    @Test
    void timeSeriesGuardAppliesOnlyPastTheLastPopulation() {
        assertFalse(InputScenario.timeSeriesEntersCachedPopulation(2023, 2023));
        assertFalse(InputScenario.timeSeriesEntersCachedPopulation(2019, 2023));
        assertTrue(InputScenario.timeSeriesEntersCachedPopulation(2024, 2023));
        var base = Map.of("gdp|2023", 1.1, "inflation|2024", 1.2);
        var changed = Map.of("gdp|2023", 1.1, "inflation|2024", 1.3);
        var e = assertThrows(IllegalStateException.class,
                () -> InputScenario.requireCachedInputsUnchanged("m", "the uprating series", "time_series_factor.xlsx", changed, base));
        assertTrue(e.getMessage().contains("inflation|2024"));
        assertDoesNotThrow(() -> InputScenario.requireCachedInputsUnchanged("m", "the uprating series", "time_series_factor.xlsx", base, base));
    }

    @Test
    void unusedWorkbookMessageListsThemAndPassesWhenNone() {
        var e = assertThrows(IllegalStateException.class,
                () -> InputScenario.requireNoUnusedWorkbooks("m", List.of("a.xlsx", "b.xlsx"), "input/PL/"));
        assertTrue(e.getMessage().contains("a.xlsx, b.xlsx"));
        assertTrue(e.getMessage().contains("input/PL/"));
        assertDoesNotThrow(() -> InputScenario.requireNoUnusedWorkbooks("m", List.of(), "input/PL/"));
    }

    @Test
    void differingCellsListsChangedAndMissingKeys() {
        var base = Map.of("Female|PL10|20", 10.0, "Male|PL10|20", 11.0, "Male|PL2|0", 5.0);
        var scen = Map.of("Female|PL10|20", 10.0, "Male|PL10|20", 11.5, "Male|PL4|0", 5.0);
        assertEquals(List.of("Male|PL10|20", "Male|PL2|0", "Male|PL4|0"), InputScenario.differingCells(scen, base));
        assertEquals(List.of(), InputScenario.differingCells(base, base));
    }
}
