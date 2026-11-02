package simpaths.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import simpaths.data.startingpop.Processed;
import simpaths.model.enums.Country;
import simpaths.model.enums.MacroFeedbackMargins;
import simpaths.model.enums.MacroLogLevel;
import simpaths.model.enums.MacroModelMode;

class SimPathsModelTest {

    /**
     * The macro defaults the documentation states. mm_macroModel is off, so a plain SimPaths
     * run has no macro layer, while the feedback margins default to on and are simply inert
     * without a Ramsey layer to re-solve. The predecessor of this test asserted that the
     * feedback with the macro model off was fatal, which was right only while the feedback
     * was an explicit opt-in.
     */
    @Test
    void testMacroSwitchDefaults() {
        SimPathsModel model = new SimPathsModel(Country.PL, 2023);
        assertEquals(MacroModelMode.OFF, model.getMm_macroModel());
        assertEquals(MacroLogLevel.OFF, model.getMm_macroLogging());
        assertEquals(MacroFeedbackMargins.EMPLOYMENT_AND_HOURS, model.getMm_ramseyFeedbackMargins());
        assertFalse(model.getMm_macroModel().usesRamseyTrend());
        assertFalse(model.getMm_macroModel().usesDsge());
    }

    /**
     * getProcessed() runs a read-only transaction; closing the EntityManager while that
     * transaction is still active defers the physical close, so a missing commit leaks one
     * pooled JDBC connection per call. Because emfStartingPopulation is static, all runs of
     * a multi-run share one Hibernate-internal pool (capped at 20 by default), and run 21
     * dies at txn.begin() with "Problem sourcing data for starting population". A tiny pool
     * makes the same exhaustion observable within a handful of calls.
     */
    @Test
    void testGetProcessedDoesNotLeakPooledConnections(@TempDir Path tempDir) throws Exception {
        Map<String, Object> props = new HashMap<>();
        props.put("hibernate.connection.url",
                "jdbc:h2:file:" + tempDir.resolve("leaktest").toString().replace('\\', '/'));
        props.put("hibernate.connection.pool_size", "5");
        EntityManagerFactory emf = Persistence.createEntityManagerFactory("starting-population", props);

        EntityManager seeder = emf.createEntityManager();
        seeder.getTransaction().begin();
        seeder.persist(new Processed(Country.PL, 2023, 999, false));
        seeder.getTransaction().commit();
        seeder.close();

        Field emfField = SimPathsModel.class.getDeclaredField("emfStartingPopulation");
        emfField.setAccessible(true);
        Object previousEmf = emfField.get(null);
        emfField.set(null, emf);
        try {
            SimPathsModel model = new SimPathsModel(Country.PL, 2023);
            Method getProcessed = SimPathsModel.class.getDeclaredMethod(
                    "getProcessed", Country.class, int.class, int.class, boolean.class);
            getProcessed.setAccessible(true);
            for (int call = 1; call <= 8; call++) {
                try {
                    getProcessed.invoke(model, Country.PL, 2023, 999, false);
                } catch (InvocationTargetException e) {
                    throw new AssertionError("getProcessed() failed on call " + call
                            + " of 8 against a pool of 5: it leaks its pooled connection", e.getCause());
                }
            }
        } finally {
            emfField.set(null, previousEmf);
            emf.close();
        }
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }
}
