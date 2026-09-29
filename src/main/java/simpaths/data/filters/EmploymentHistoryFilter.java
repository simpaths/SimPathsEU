package simpaths.data.filters;

import microsim.statistics.ICollectionFilter;
import simpaths.model.Person;
import simpaths.model.enums.Les_c4;

/**
 * Filter that keeps only persons whose previous-period (lag1) labour status
 * matches the supplied {@link Les_c4} value. Used by {@link simpaths.data.statistics.LabourStatistics}
 * to compute labour-market transition rates.
 */
public class EmploymentHistoryFilter implements ICollectionFilter {

    private final Les_c4 employmentLag1;

    public EmploymentHistoryFilter(Les_c4 employmentLag1) {
        super();
        this.employmentLag1 = employmentLag1;
    }

    @Override
    public boolean isFiltered(Object object) {
        if (object instanceof Person) {
            Person person = (Person) object;
            return person.getLes_c4_lag1() != null && person.getLes_c4_lag1().equals(employmentLag1);
        }
        throw new IllegalArgumentException("Argument passed to EmploymentHistoryFilter must be of object type Person");
    }
}
