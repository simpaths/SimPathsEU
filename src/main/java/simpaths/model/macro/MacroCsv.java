package simpaths.model.macro;

import java.util.ArrayList;
import java.util.List;

/**
 * Shared row/field handling for the macro package's CSV readers.
 *
 * <p><b>Why this class exists.</b> The package carried several hand-rolled parse
 * loops with different strictness, and two of them — {@link RamseyScenario} and
 * {@link DSGEShockScenario}, which read the same family of scenario files — had
 * already drifted apart in two ways that both fail silently:</p>
 *
 * <ul>
 *   <li>{@code split(",")} drops trailing empty fields, so a row ending in
 *       {@code ,,} yields fewer columns than the header declares and the last
 *       shock column is never assigned. {@code split(",", -1)} keeps them.</li>
 *   <li>{@code Double.parseDouble("NaN")} succeeds. A NaN shock then enters the
 *       DSGE state, and because every comparison against NaN is false the ±bound
 *       stability guard does <em>not</em> fire — the run continues and every
 *       downstream number is NaN.</li>
 * </ul>
 *
 * <p>Both readers now go through here, so the two behaviours are one decision
 * rather than two.</p>
 */
final class MacroCsv {

    private MacroCsv() {
    }

    /**
     * Split a CSV row, keeping trailing empty fields and tolerating a CR left by
     * a CRLF file read on a platform that split on LF alone.
     */
    static String[] splitRow(String line) {
        String cleaned = line.endsWith("\r") ? line.substring(0, line.length() - 1) : line;
        return cleaned.split(",", -1);
    }

    /**
     * Drop blank lines and {@code #} / {@code //} comment lines, preserving order.
     * Surviving lines are returned trimmed.
     */
    static List<String> stripCommentsAndBlanks(List<String> allLines) {
        List<String> lines = new ArrayList<>();
        for (String line : allLines) {
            String trimmed = line.trim();
            if (!trimmed.isEmpty() && !trimmed.startsWith("#") && !trimmed.startsWith("//")) {
                lines.add(trimmed);
            }
        }
        return lines;
    }

    /**
     * Parse a scenario cell that must be a finite number.
     *
     * @throws IllegalArgumentException if the text is unparseable, NaN, or infinite
     */
    static double requireFinite(String raw, int rowNumber, String column, Object source) {
        double parsed;
        try {
            parsed = Double.parseDouble(raw);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(String.format(
                    "Invalid number at row %d, column '%s' in %s: '%s'",
                    rowNumber, column, source, raw));
        }
        if (!Double.isFinite(parsed)) {
            throw new IllegalArgumentException(String.format(
                    "Invalid non-finite number at row %d, column '%s' in %s: '%s'. "
                  + "A NaN or infinite shock propagates through the state vector without "
                  + "tripping the stability bound, because every comparison against NaN is false.",
                    rowNumber, column, source, raw));
        }
        return parsed;
    }
}
