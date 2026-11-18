package simpaths.experiment;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class OutputReadmeTest {

    @Test
    void inputScenarioParagraphListsTheReplacedWorkbooks() {
        String text = OutputReadme.inputScenarioParagraph("PL", "migration_200k", List.of("align_popProjections.xlsx"));
        assertEquals("**This run replaced input workbooks** with the files in `input/PL/scenarios/migration_200k/`: "
                + "align_popProjections.xlsx. Compare it with a run without this scenario, not with the baseline's documentation.",
                text);
    }

    @Test
    void inputScenarioParagraphSaysWhenNoWorkbookIsReplaced() {
        String text = OutputReadme.inputScenarioParagraph("PL", "ramsey_only", List.of());
        assertTrue(text.contains("replaces no workbook"), text);
        assertTrue(text.contains("`input/PL/scenarios/ramsey_only/`"), text);
        assertFalse(text.contains(": ."), text);
    }
}
