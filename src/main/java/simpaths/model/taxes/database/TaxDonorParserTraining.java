package simpaths.model.taxes.database;


import javax.swing.*;
import java.io.File;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.*;

import simpaths.data.FormattedDialogBox;
import simpaths.data.Parameters;
import simpaths.model.enums.Country;


/**
 *
 * CLASS TO MANAGE TRANSLATION OF CSV DATA FROM EUROMOD TO DATABASE FOR DONORS USED TO IMPUTE TAX AND BENEFIT PAYMENTS
 * Variant of {@link TaxDonorDataParser} that operates on training data, which lacks DEH (highest education),
 * DRGN1 (region — present in the file but always 0) and LCS (civil servant indicator). Training data now
 * includes the country-specific tax-unit identifier again, so TUID is derived from the same
 * tu_fambu_<country>_headid column as in the main parser.
 *
 */
public class TaxDonorParserTraining {

    // Static variables present in the training tax-donor CSV (subset of Parameters.DONOR_STATIC_VARIABLES).
    // Excludes deh, drgn1 and lcs; the country-specific benefit-unit identifier is appended dynamically.
    public static final String[] DONOR_STATIC_VARIABLES_TRAINING = new String[]{
            "idhh",                    //id of household
            "idperson",                //id of person
            "idfather",                //id of father
            "idmother",                //id of mother
            "idpartner",               //id of partner
            "dag",                     //age
            "dct",                     //country
            "dgn",                     //gender
            "dwt",                     //household weight
            "les",                     //labour employment status + health status
            "lhw",                     //hours worked per week
            "ddi",                     //disability status
            "yem",                     //employment income - used to construct work sector
            "yse",                     //self-employment income - used to construct work sector
    };


    /**
     * ENTRY POINT FOR MANAGER
     *
     * @param country country object, defines the country code
     * @param startYear first simulated year
     */
    public static void databaseFromCSV(Country country, int startYear, boolean isVisible) {

        String title = "Creating donor database tables (training data)";
        JFrame csvFrame = null;
        if (isVisible) {
            String text = "<html><h2 style=\"text-align: center; font-size:120%; padding: 10pt\">"
                    + "Constructing donor database tables for imputing tax and benefit payments (training data)</h2></html>";
            csvFrame = FormattedDialogBox.create(title, text, 800, 120, null, false, false, isVisible);
        }
        System.out.println(title);

        Parameters.setCountryBenefitUnitName(); // Specify names of benefit unit variables in EUROMOD

        Connection conn = null;
        try {
            Class.forName("org.h2.Driver");
            conn = DriverManager.getConnection(TaxDonorDataParser.getInputDatabaseJdbcUrl(), "sa", "");

            createTaxDonorTables(conn, country, startYear);
            TaxDonorDataParser.updateDefaultDonorTables(conn, country);

            conn.close();
            conn = null;
        }
        catch (ClassNotFoundException | SQLException e) {
            if (e instanceof ClassNotFoundException) {
                System.out.println("ERROR: Class not found: " + e.getMessage() + "\nCheck that the input.h2.db "
                        + "exists in the input folder.  If not, unzip the input.h2.zip file and store the resulting "
                        + "input.h2.db in the input folder!\n");
            } else {
                throw new IllegalArgumentException("SQL Exception thrown! " + e.getMessage());
            }
        }
        finally {
            try {
                if (conn != null) conn.close();
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }

        if (csvFrame != null) csvFrame.setVisible(false);
    }


    /**
     *
     * METHOD TO INITIALISE PERSON-LEVEL RELATIONAL DATABASE TABLES FOR DONORS AND POPULATE FROM TRAINING CSV DATA
     *
     */
    private static void createTaxDonorTables(Connection conn, Country country, int startYear) {

        String taxDonorInputFileName = Parameters.getTaxDonorInputFileName();
        String donorInputFileLocation = Parameters.INPUT_DIRECTORY + taxDonorInputFileName + ".csv";

        Statement stat = null;
        try {
            stat = conn.createStatement();
            stat.execute(
                "DROP TABLE IF EXISTS " + taxDonorInputFileName + " CASCADE;"
                + "CREATE TABLE " + taxDonorInputFileName + " AS SELECT * FROM CSVREAD('" + donorInputFileLocation + "');"
            );

            //---------------------------------------------------------------------------
            //	DonorPerson table
            //---------------------------------------------------------------------------
            String personTableName = "DONORPERSON_" + country;

            Set<String> inputPersonStaticColumnNames = new LinkedHashSet<>(Arrays.asList(DONOR_STATIC_VARIABLES_TRAINING));
            inputPersonStaticColumnNames.add((String) Parameters.getBenefitUnitVariableNames().getValue(country.getCountryName()));

            stat.execute(

                "DROP TABLE IF EXISTS " + personTableName + " CASCADE;"
                + "CREATE TABLE " + personTableName + " AS (SELECT " + TaxDonorDataParser.stringAppender(inputPersonStaticColumnNames) + " FROM " + taxDonorInputFileName + ");"

                //Add id column
                + "ALTER TABLE " + personTableName + " ALTER COLUMN idperson RENAME TO ID;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN ID BIGINT NOT NULL;"
                + "ALTER TABLE " + personTableName + " ADD PRIMARY KEY (ID);"

                //Tax unit identifier
                + "ALTER TABLE " + personTableName + " ALTER COLUMN " + Parameters.getBenefitUnitVariableNames().getValue(country.getCountryName()) + " RENAME TO TUID;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN TUID BIGINT;"

                //Age
                + "ALTER TABLE " + personTableName + " ALTER COLUMN DAG int NOT NULL;"

                //Country
                + "ALTER TABLE " + personTableName + " ADD COUNTRY VARCHAR_IGNORECASE;"
                + "UPDATE " + personTableName + " SET COUNTRY = '" + country + "' WHERE DCT = " + country.getEuromodCountryCode() + ";"
                + "ALTER TABLE " + personTableName + " DROP COLUMN DCT;"

                //Gender
                + "ALTER TABLE " + personTableName + " ADD GENDER VARCHAR_IGNORECASE;"
                + "UPDATE " + personTableName + " SET GENDER = 'Female' WHERE DGN = 0;"
                + "UPDATE " + personTableName + " SET GENDER = 'Male' WHERE DGN = 1;"
                + "ALTER TABLE " + personTableName + " DROP COLUMN DGN;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN GENDER RENAME TO DGN;"
            );
            stat.execute(

                //Weights
                "ALTER TABLE " + personTableName + " ALTER COLUMN DWT RENAME TO WEIGHT;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN WEIGHT double;"

                //Labour Market Economic Status
                + "ALTER TABLE " + personTableName + " ADD ACTIVITY_STATUS VARCHAR_IGNORECASE;"
                + "UPDATE " + personTableName + " SET ACTIVITY_STATUS = 'EmployedOrSelfEmployed' WHERE LES >= 1 AND LES <= 3;"
                + "UPDATE " + personTableName + " SET ACTIVITY_STATUS = 'Student' WHERE LES = 0 OR LES = 6;"
                + "UPDATE " + personTableName + " SET ACTIVITY_STATUS = 'Retired' WHERE LES = 4;"
                + "UPDATE " + personTableName + " SET ACTIVITY_STATUS = 'NotEmployed' WHERE LES = 5 OR LES >= 7;"

                //Health
                + "ALTER TABLE " + personTableName + " ADD HEALTH VARCHAR_IGNORECASE;"
                + "UPDATE " + personTableName + " SET HEALTH = 'Good' WHERE LES != 8;"
                + "UPDATE " + personTableName + " SET HEALTH = 'Poor' WHERE LES = 8;"
                + "ALTER TABLE " + personTableName + " DROP COLUMN LES;"

                //Long-term sick and disabled
                + "ALTER TABLE " + personTableName + " ALTER COLUMN DDI int;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN DDI RENAME TO DLLTSD;"

                //Labour hours
                + "ALTER TABLE " + personTableName + " ALTER COLUMN LHW int;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN LHW RENAME TO " + Parameters.HOURS_WORKED_WEEKLY.toUpperCase() + ";"
            );

            //Work sector - training data lacks LCS, so the Public_Employee override is omitted.
            stat.execute(
                "ALTER TABLE " + personTableName + " ADD WORK_SECTOR VARCHAR_IGNORECASE DEFAULT 'Private_Employee';"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN YEM DOUBLE;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN YSE DOUBLE;"
                + "UPDATE " + personTableName + " SET WORK_SECTOR = 'Self_Employed' WHERE abs(YEM) < abs(YSE);"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN YEM RENAME TO EMPLOYMENT_INCOME;"
                + "ALTER TABLE " + personTableName + " ALTER COLUMN YSE RENAME TO SELF_EMPLOYMENT_INCOME;"

                + "SELECT * FROM " + personTableName + " ORDER BY ID;"
            );


            //---------------------------------------------------------------------------
            //	DonorPersonPolicy table — verbatim from TaxDonorDataParser
            //---------------------------------------------------------------------------
            String personPolicyTableName = "DONORPERSONPOLICY_" + country;

            StringBuilder varList1 = new StringBuilder("PID VARCHAR, FROM_YEAR INT, SYSTEM_YEAR INT");
            StringBuilder varList2 = new StringBuilder("PID");
            for (String variable: Parameters.DONOR_POLICY_VARIABLES) {
                varList1.append(", ").append(variable.toUpperCase()).append(" VARCHAR");
                varList2.append(", ").append(variable.toUpperCase());
            }

            stat.execute(
                "DROP TABLE IF EXISTS " + personPolicyTableName + " CASCADE;"
                + "CREATE TABLE " + personPolicyTableName + " (ID BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, " + varList1 + ");"
            );

            for (Integer fromYear: Parameters.EUROMODpolicyScheduleSystemYearMap.keySet()) {

                String systemName = Parameters.EUROMODpolicyScheduleSystemYearMap.get(fromYear).getKey();
                Integer systemYear = Parameters.EUROMODpolicyScheduleSystemYearMap.get(fromYear).getValue();
                Set<String> inputPersonDynamicColumnNames = new LinkedHashSet<>(0);
                inputPersonDynamicColumnNames.add("IDPERSON");
                for (String variable: Parameters.DONOR_POLICY_VARIABLES) {
                    inputPersonDynamicColumnNames.add(variable + "_" + systemName);
                }

                stat.execute(
                    "INSERT INTO " + personPolicyTableName + " (" + varList2 + ")"
                    + " SELECT " + TaxDonorDataParser.stringAppender(inputPersonDynamicColumnNames) + " FROM " + taxDonorInputFileName + ";"
                );
                stat.execute(
                    "UPDATE " + personPolicyTableName + " SET SYSTEM_YEAR = " + systemYear + " WHERE SYSTEM_YEAR IS NULL;"
                    + "UPDATE " + personPolicyTableName + " SET FROM_YEAR = " + fromYear + " WHERE FROM_YEAR IS NULL;"
                );
            }
            stat.execute(
                "ALTER TABLE " + personPolicyTableName + " ALTER COLUMN PID BIGINT;"
            );
            for (String variable: Parameters.DONOR_POLICY_VARIABLES) {
                stat.execute("ALTER TABLE " + personPolicyTableName + " ALTER COLUMN " + variable + " DOUBLE;");
            }


            //---------------------------------------------------------------------------
            //	DonorTaxUnit table
            //---------------------------------------------------------------------------
            String taxUnitTableName = "DONORTAXUNIT_" + country;
            stat.execute(
                // one row per tuid, carrying the tax unit's weight. EUROMOD output normally holds a household-level
                // weight in dwt, which is constant within a tax unit; some country datasets (e.g. ES) supply a
                // person-level weight instead, so the weight is averaged over the members of the tax unit.
                "DROP TABLE IF EXISTS " + taxUnitTableName + " CASCADE;"
                + "CREATE TABLE " + taxUnitTableName + " AS (SELECT TUID, AVG(WEIGHT) AS WEIGHT FROM " + personTableName + " GROUP BY TUID ORDER BY TUID);"

                + "ALTER TABLE " + taxUnitTableName + " ALTER COLUMN TUID RENAME TO ID;"
                + "ALTER TABLE " + taxUnitTableName + " ALTER COLUMN ID BIGINT NOT NULL;"
                + "ALTER TABLE " + taxUnitTableName + " ADD PRIMARY KEY (ID);"
                + "SELECT * FROM " + taxUnitTableName + " ORDER BY ID;"
            );


            //---------------------------------------------------------------------------
            //	DonorTaxUnitPolicy table — empty skeleton, populated by populateDonorTaxUnitTables
            //---------------------------------------------------------------------------
            String taxUnitPolicyTableName = "DONORTAXUNITPOLICY_" + country;
            StringBuilder varList = new StringBuilder("TUID LONG, FROM_YEAR INT, SYSTEM_YEAR INT");

            stat.execute(
                "DROP TABLE IF EXISTS " + taxUnitPolicyTableName + " CASCADE;"
                + "CREATE TABLE " + taxUnitPolicyTableName + " (ID BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, " + varList + ");"
            );


            //---------------------------------------------------------------------------
            //  Foreign keys
            //---------------------------------------------------------------------------
            stat.execute(
                "ALTER TABLE " + personTableName + " ADD FOREIGN KEY (TUID) REFERENCES " + taxUnitTableName + " (ID);"
                + "ALTER TABLE " + taxUnitPolicyTableName + " ADD FOREIGN KEY (TUID) REFERENCES " + taxUnitTableName + " (ID);"
                + "ALTER TABLE " + personPolicyTableName + " ADD FOREIGN KEY (PID) REFERENCES " + personTableName + " (ID);"
            );


            //---------------------------------------------------------------------------
            //  Clean-up
            //---------------------------------------------------------------------------
            stat.execute("DROP TABLE IF EXISTS " + taxDonorInputFileName + " CASCADE;");

        }
        catch (SQLException e) {
            throw new IllegalArgumentException("SQL Exception thrown!" + e.getMessage());
        }
        finally {
            try {
                if (stat != null) stat.close();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}
