package simpaths.model;

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

class SimPathsModelTest {

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
}
