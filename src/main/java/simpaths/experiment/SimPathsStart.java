// define package
package simpaths.experiment;

// import Java packages
import java.awt.Dimension;
import org.apache.commons.cli.*;
import java.awt.Toolkit;
import java.io.*;
import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicReference;
import javax.swing.BorderFactory;
import javax.swing.BoxLayout;
import javax.swing.JInternalFrame;
import javax.swing.plaf.basic.BasicInternalFrameUI;
import javax.swing.JPanel;

// third-party packages
import simpaths.data.startingpop.DataParser;
import simpaths.model.SimPathsModel;
import org.apache.commons.io.FileUtils;

// import JAS-mine packages
import microsim.data.ExperimentManager;
import microsim.data.MultiKeyCoefficientMap;
import microsim.data.db.DatabaseUtils;
import microsim.data.excel.ExcelAssistant;
import microsim.engine.ExperimentBuilder;
import microsim.engine.SimulationEngine;
import microsim.event.SystemEventType;
import microsim.gui.shell.MicrosimShell;

// import SimPaths packages
import simpaths.model.enums.Country;
import simpaths.data.*;
import simpaths.model.taxes.database.TaxDonorDataParser;
import simpaths.model.taxes.database.TaxDonorParserTraining;


/**
 *
 * 	CLASS FOR SINGLE SIMULATION EXECUTION
 *
 */
public class SimPathsStart implements ExperimentBuilder {

	// default simulation parameters
	private static Country country = Country.PL;
	private static int startYear = Parameters.getMaxStartYear();
	private static int endYear = 2013;
	private static int popSize = 30000;

	private static boolean showGui = true;  // Show GUI by default

	private static boolean setupOnly = false;

	private static boolean rewritePolicySchedule = false;

	private static boolean reuseExistingDatabase = true;
	private static final boolean defaultReuseExistingDatabase = reuseExistingDatabase;

	// Tracks whether -t/--training was given on the command line. When false, the
	// auto-detect (empty InitialPopulations folder → flip to training) is allowed
	// to run; when true, the explicit CLI value wins and auto-detect is skipped.
	private static boolean trainingFlagExplicit = false;


	/**
	 *
	 * 	MAIN class for simulation entry
	 *
	 */
	public static void main(String[] args) {

		if (!parseCommandLineArgs(args)) {
			// If parseCommandLineArgs returns false (indicating help option is provided), exit main
			return;
		}

		if (showGui) {
			// display dialog box to allow users to define desired simulation
			runGUIdialog();
		} else {
			try {
				runGUIlessSetup(4);
			} catch (FileNotFoundException f) {
				System.err.println(f.getMessage());
			};
		}

		if (setupOnly) {
			System.out.println("Setup complete, exiting.");
			return;
		}

		// Determine the country-specific input path
		String dbCountryYearPath = Parameters.INPUT_DIRECTORY	 + File.separator + Parameters.DatabaseCountryYearFilename + ".xlsx";


		// Load last used country and year from Excel, if it exists
		MultiKeyCoefficientMap lastDatabaseCountryAndYear = null;
		File dbFile = new File(dbCountryYearPath);
		if (dbFile.exists()) {
			lastDatabaseCountryAndYear = ExcelAssistant.loadCoefficientMap(dbCountryYearPath, "Data", 1);
		}

		// If Excel file exists, read country and startYear; otherwise, use GUI to select
		if (lastDatabaseCountryAndYear != null) {
			// Determine the country from the Excel file
			if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[EL]"))) {
				country = Country.EL;
			} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[IT]"))) {
				country = Country.IT;
			} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[ES]"))) {
				country = Country.ES;
			} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[HU]"))) {
				country = Country.HU;
			} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[PL]"))) {
				country = Country.PL;
			} else {
				throw new IllegalArgumentException("Country not recognised in Excel file. Please select one of the available countries (EL, IT, ES, HU, PL).");
			}

			// Set startYear from Excel
			String valueYear = lastDatabaseCountryAndYear.getValue(country.toString()).toString();
			startYear = Integer.parseInt(valueYear);
		} else {
			// File does not exist: first run, let user select country and year via GUI
			System.out.println("No previous country/year file found in " + dbCountryYearPath + ". Please select country and start year.");
			chooseCountryAndStartYear(); // GUI will update `country` and `startYear` and create the Excel file
		}

		// From here on, use countryInputPath for all future file reads/writes
		// e.g., EUROMODpolicySchedule.xlsx: countryInputPath + File.separator + Parameters.EUROMODpolicyScheduleFilename + ".xlsx"

		if (!showGui) {
			// Keep headless single-run aligned with the database created during setup.
			ExperimentManager.getInstance().copyInputFolderStructure = false;
			DatabaseUtils.databaseInputUrl = "input" + File.separator + "input";
		}

		// start the JAS-mine simulation engine
		final SimulationEngine engine = SimulationEngine.getInstance();
		MicrosimShell gui = null;
		if (showGui) {
			gui = new MicrosimShell(engine);
			gui.setVisible(true);
		}
		SimPathsStart experimentBuilder = new SimPathsStart();
		engine.setExperimentBuilder(experimentBuilder);
		engine.setup();
		if (!showGui) {
			runHeadlessSimulation(engine);
		}
	}

	private static void runHeadlessSimulation(SimulationEngine engine) {
		CountDownLatch simulationFinished = new CountDownLatch(1);
		AtomicReference<Throwable> simulationFailure = new AtomicReference<>();

		// Headless JAS-mine runs are asynchronous, so wait for the model's End event before quitting.
		engine.addEngineListener(type -> {
			if (type == SystemEventType.End || type == SystemEventType.Shutdown) {
				simulationFinished.countDown();
			}
		});
		engine.setUncaughtExceptionHandler((thread, throwable) -> {
			simulationFailure.compareAndSet(null, throwable);
			simulationFinished.countDown();
		});

		engine.startSimulation();

		try {
			simulationFinished.await();
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
			throw new RuntimeException("Interrupted while waiting for the simulation to finish.", e);
		}

		Throwable failure = simulationFailure.get();
		if (failure != null) {
			throw new RuntimeException("Simulation failed before completion.", failure);
		}

		engine.quit();
	}

	private static boolean parseCommandLineArgs(String[] args) {
		resetCommandLineState();

		Options options = new Options();

		Option countryOption = new Option("c", "country", true, "Country (by country code CC, e.g. 'UK'/'IT')");
		countryOption.setArgName("CC");
		options.addOption(countryOption);

		Option startYearOption = new Option("s", "startYear", true, "Start year");
		startYearOption.setArgName("year");
		options.addOption(startYearOption);

		Option endYearOption = new Option("e", "endYear", true, "End year");
		endYearOption.setArgName("year");
		options.addOption(endYearOption);

		Option popSizeOption = new Option("p", "popSize", true, "Population size");
		popSizeOption.setArgName("int");
		options.addOption(popSizeOption);

		Option setupOption = new Option("Setup", "Setup only");
		options.addOption(setupOption);

		Option rewritePolicyScheduleOption = new Option("r", "rewrite-policy-schedule",false, "Re-write policy schedule from detected policy files");
		options.addOption(rewritePolicyScheduleOption);

		Option reuseExistingDatabaseOption = Option.builder()
				.longOpt("reuse-existing-db")
				.desc("Reuse input/input.mv.db instead of rebuilding it when running headless")
				.build();
		options.addOption(reuseExistingDatabaseOption);

		Option rebuildDatabaseOption = Option.builder()
				.longOpt("rebuild-db")
				.desc("Force a rebuild of input/input.mv.db instead of reusing it when running headless")
				.build();
		options.addOption(rebuildDatabaseOption);

		Option guiOption = new Option("g", "showGui", true, "Show GUI");
		guiOption.setArgName("true/false");
		options.addOption(guiOption);

		Option trainingOption = new Option("t", "training", true, "Use training data subset (InitialPopulations/training, EUROMODoutput/training, TaxDonorParserTraining)");
		trainingOption.setArgName("true/false");
		options.addOption(trainingOption);

		Option helpOption = new Option("h", "help", false, "Print help message");
		options.addOption(helpOption);

		CommandLineParser parser = new DefaultParser();
		HelpFormatter formatter = new HelpFormatter();
		formatter.setOptionComparator(null);

		try {
			CommandLine cmd = parser.parse(options, args);

			if (cmd.hasOption("h")) {
				printHelpMessage(formatter, options);
				return false; // Exit without reporting an error
			}

			if (cmd.hasOption("g")) {
				showGui = Boolean.parseBoolean(cmd.getOptionValue("g"));
			}

			if (cmd.hasOption("t")) {
				boolean trainingValue = Boolean.parseBoolean(cmd.getOptionValue("t"));
				Parameters.setTrainingFlag(trainingValue);
				trainingFlagExplicit = true;
				System.out.println("Training-data flag set explicitly via CLI: -t " + trainingValue);
			}

			if (cmd.hasOption("c")) {
				try {
					country = Country.valueOf(cmd.getOptionValue("c"));
				} catch (Exception e) {
					throw new IllegalArgumentException("Code '" + cmd.getOptionValue("c") + "' not a valid country.");
				}
			}

			if (cmd.hasOption("s")) {
				startYear = Integer.parseInt(cmd.getOptionValue("s"));
			}

			if (cmd.hasOption("e")) {
				endYear = Integer.parseInt(cmd.getOptionValue("e"));
			}

			if (cmd.hasOption("p")) {
				popSize = Integer.parseInt(cmd.getOptionValue("p"));
			}

			if (cmd.hasOption("Setup")) {
				setupOnly = true;
			}

			if (cmd.hasOption("r")) {
				rewritePolicySchedule = true;
			}

			if (cmd.hasOption("reuse-existing-db")) {
				reuseExistingDatabase = true;
			}

			if (cmd.hasOption("rebuild-db")) {
				reuseExistingDatabase = false;
			}

			if (setupOnly) {
				reuseExistingDatabase = false;
			}
		} catch (ParseException | IllegalArgumentException e) {
			System.err.println("Error parsing command line arguments: " + e.getMessage());
			formatter.printHelp("SimPathsStart", options);
			return false;
		}

		return true;
	}

	private static void printHelpMessage(HelpFormatter formatter, Options options) {
		String header = "SimPathsStart will start the SimPaths run. " +
				"When using the argument `Setup`, this will create the population database " +
				"and exit before starting the first run. " +
				"It takes the following options:";
		String footer = "When running with no display, `-g` must be set to `false`.";
		formatter.printHelp("SimPathsStart", header, options, footer, true);
	}

	private static void resetCommandLineState() {
		country = Country.PL;
		startYear = Parameters.getMaxStartYear();
		endYear = 2013;
		popSize = 30000;
		showGui = true;
		setupOnly = false;
		rewritePolicySchedule = false;
		reuseExistingDatabase = defaultReuseExistingDatabase;
		trainingFlagExplicit = false;
	}


	/**
	 *
	 * METHOD TO START SELECTED EXPERIMENT
	 * ROUTED FROM JAS-mine 'engine.setup()'
	 * @param engine
	 *
	 */
	@Override
	public void buildExperiment(SimulationEngine engine) {

		// instantiate simulation processes
		SimPathsModel model = new SimPathsModel(country, startYear);
		model.setEndYear(endYear);
		model.setPopSize(popSize);
		SimPathsCollector collector = new SimPathsCollector(model);

		engine.addSimulationManager(model);
		engine.addSimulationManager(collector);
		if (showGui) {
			SimPathsObserver observer = new SimPathsObserver(model, collector);
			engine.addSimulationManager(observer);
		}

		model.setCollector(collector);
	}

	private static void runGUIlessSetup(int option) throws FileNotFoundException {

		// Auto-detect training mode only when -t/--training was NOT passed on the command line.
		// If actual InitialPopulations/<country>/*.csv is empty, fall back to training data.
		if (!trainingFlagExplicit) {
			Collection<File> testList = FileUtils.listFiles(new File(Parameters.getInputDirectoryInitialPopulations(country)), new String[]{"csv"}, false);
			if (testList.size() == 0) {
				Parameters.setTrainingFlag(true);
				System.out.println("No CSV files found under " + Parameters.getInputDirectoryInitialPopulations(country)
						+ " — auto-switching to training data (Parameters.trainingFlag = true).");
			}
		}

		writeSelectedCountryAndYear();

		if (reuseExistingDatabase) {
			File inputDatabase = new File("input" + File.separator + "input.mv.db");
			if (inputDatabase.exists()) {
				Parameters.defineCountryString(country);
				return;
			}
			System.out.println("Input database '" + inputDatabase.getPath() + "' not found. Rebuilding it.");
		}

		// Build path for the country-specific input folder
		String countryInputPath = "input" + File.separator + country.toString();

        // Create EUROMODPolicySchedule input from files
		File policyScheduleFile = new File(
				countryInputPath + File.separator + Parameters.EUROMODpolicyScheduleFilename + ".xlsx"
		);

		if (!rewritePolicySchedule && !policyScheduleFile.exists()) {
			throw new FileNotFoundException("Policy Schedule file '" +
					policyScheduleFile.getPath() + "' doesn't exist. " +
					"Provide excel file or use `--rewrite-policy-schedule` to re-construct from available policy files.");
		}

		if (rewritePolicySchedule) {
			writePolicyScheduleExcelFile();
		}

		// load uprating factors
		Parameters.loadTimeSeriesFactorMaps(country);
		Parameters.instantiateAlignmentMaps();

        // define country string for Parameters
        Parameters.defineCountryString(country);
		// set-up database
		Parameters.databaseSetup(country, showGui, startYear);
	}

	private static void writeSelectedCountryAndYear() {
		String rootInputPath = "input";
		File rootFolder = new File(rootInputPath);
		if (!rootFolder.exists()) {
			rootFolder.mkdirs();
		}

		String[] columnNames = {"Country", "Year"};
		Object[][] data = new Object[1][columnNames.length];
		data[0][0] = country.toString();
		data[0][1] = startYear;

		XLSXfileWriter.createXLSX(
				rootInputPath,
				Parameters.DatabaseCountryYearFilename,
				"Data",
				columnNames,
				data
		);
	}

	public static void writePolicyScheduleExcelFile() {

		Collection<File> euromodOutputTextFiles = FileUtils.listFiles(new File(Parameters.getEuromodOutputDirectory(country)), new String[]{"txt"}, false);
		Iterator<File> fIter = euromodOutputTextFiles.iterator();
		while (fIter.hasNext()) {
			File file = fIter.next();
			if (file.getName().endsWith("_EMHeader.txt")) {
				fIter.remove();
			}
		}

		// create table to allow user specification of policy environment
		String[] columnNames = {
				Parameters.EUROMODpolicyScheduleHeadingFilename,
				Parameters.EUROMODpolicyScheduleHeadingScenarioYearBegins.replace('_', ' '),
				Parameters.EUROMODpolicyScheduleHeadingScenarioSystemYear.replace('_', ' '),
				Parameters.EUROMODpolicySchedulePlanHeadingDescription
		};
		Object[][] data = new Object[euromodOutputTextFiles.size()][columnNames.length];
		int row = 0;
		for (File file: euromodOutputTextFiles) {
			String name = file.getName();
			data[row][0] = name;
			data[row][1] = name.split("_")[1];
			data[row][2] = name.split("_")[1];
			data[row][3] = "";
			row++;
		}

		XLSXfileWriter.createXLSX(
				"input" + File.separator + country.toString(),
				Parameters.EUROMODpolicyScheduleFilename,
				country.toString(),
				columnNames,
				data
		);
	}


	/**
	 *
	 * 	Display dialog box to allow users to define desired simulation
	 *
	 */
	private static void runGUIdialog() {

		int count;

		// initiate radio buttons to define policy environment and input database
		count = 0;
		Map<String,Integer> startUpOptionsStringsMap = new LinkedHashMap<>();
		startUpOptionsStringsMap.put("Change country and/or simulation start year", count++);
		startUpOptionsStringsMap.put("Load new input data for starting populations", count++);
		startUpOptionsStringsMap.put("Use UKMOD Light to alter description of tax and benefit systems", count++);
		startUpOptionsStringsMap.put("Load new input data for tax and benefit systems", count++);
		startUpOptionsStringsMap.put("Select tax and benefit systems for analysis", count++);
		StartUpCheckBoxes startUpOptions = new StartUpCheckBoxes(startUpOptionsStringsMap);

		// combine button groups into a single form component
		JInternalFrame initialisationFrame = new JInternalFrame();
		BasicInternalFrameUI bi = (BasicInternalFrameUI)initialisationFrame.getUI();
		bi.setNorthPane(null);
		initialisationFrame.setBorder(null);
		startUpOptions.setBorder(BorderFactory.createTitledBorder("options for policy environment and input database"));
		initialisationFrame.setLayout(new BoxLayout(initialisationFrame.getContentPane(), BoxLayout.PAGE_AXIS));
		initialisationFrame.add(startUpOptions);
		initialisationFrame.add(new JPanel());
		initialisationFrame.setVisible(true);

		// text for GUI
		String title = "Start-up Options";
		String text = "<html><h2 style=\"text-align: center; font-size:120%;\">Choose the start-up processes for the simulation</h2>";

		// sizing for GUI
		int height = 280, width = 550;
		Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
		if (screenSize.width < 850) {
			width = (int) (screenSize.width * 0.95);
		}

		// display GUI
		FormattedDialogBox.create(title, text, width, height, initialisationFrame, true, true, true);

		// get data returned from GUI
		boolean[] choices = startUpOptions.getChoices();

		if (choices[0]) {
			// choose the country and the simulation start year
			if (!trainingFlagExplicit) {
				Collection<File> testList = FileUtils.listFiles(new File(Parameters.getInputDirectoryInitialPopulations(country)), new String[]{"csv"}, false);
				if (testList.size() == 0) {
					Parameters.setTrainingFlag(true);
					System.out.println("No CSV files found under " + Parameters.getInputDirectoryInitialPopulations(country)
							+ " — auto-switching to training data (Parameters.trainingFlag = true).");
				}
			}
			chooseCountryAndStartYear();
		}

		String taxDonorInputFilename = "tax_donor_population_" + country;
		Parameters.setTaxDonorInputFileName(taxDonorInputFilename);

		if (choices[0] || choices[1]) {
			DataParser.databaseFromCSV(country, showGui); // Initial database tables
		}

		if (choices[2]) {
			CallEMLight.run(); // run EUROMOD Light
		}

		if (choices[0] || choices[2] || choices[3] || choices[4]) {

			// Load previously stored values for policy description and initiation year
			String countryInputPath = "input" + File.separator + country.toString();
			MultiKeyCoefficientMap previousEUROMODfileInfo = ExcelAssistant.loadCoefficientMap(
					countryInputPath + File.separator + Parameters.EUROMODpolicyScheduleFilename + ".xlsx",
					country.toString(),
					1
			);

			Collection<File> euromodOutputTextFiles = FileUtils.listFiles(new File(Parameters.getEuromodOutputDirectory(country)), new String[]{"txt"}, false);
			euromodOutputTextFiles.removeIf(file -> file.getName().endsWith("_EMHeader.txt"));

			// create table to allow user specification of policy environment
			String[] columnNames = {
					Parameters.EUROMODpolicyScheduleHeadingFilename,
					Parameters.EUROMODpolicyScheduleHeadingScenarioYearBegins.replace('_', ' '),
					Parameters.EUROMODpolicyScheduleHeadingScenarioSystemYear.replace('_', ' '),
					Parameters.EUROMODpolicySchedulePlanHeadingDescription
			};

			Object[][] data = new Object[euromodOutputTextFiles.size()][columnNames.length];
			int row = 0;
			for (File file : euromodOutputTextFiles) {
				String name = file.getName();
				data[row][0] = name;
				data[row][1] = previousEUROMODfileInfo.getValue(name, Parameters.EUROMODpolicyScheduleHeadingScenarioYearBegins) != null
						? previousEUROMODfileInfo.getValue(name, Parameters.EUROMODpolicyScheduleHeadingScenarioYearBegins).toString()
						: "";
				data[row][2] = previousEUROMODfileInfo.getValue(name, Parameters.EUROMODpolicyScheduleHeadingScenarioSystemYear) != null
						? previousEUROMODfileInfo.getValue(name, Parameters.EUROMODpolicyScheduleHeadingScenarioSystemYear).toString()
						: "";
				data[row][3] = previousEUROMODfileInfo.getValue(name, Parameters.EUROMODpolicySchedulePlanHeadingDescription) != null
						? previousEUROMODfileInfo.getValue(name, Parameters.EUROMODpolicySchedulePlanHeadingDescription).toString()
						: "";
				row++;
			}

			String titleEUROMODtable = "Update EUROMOD Policy Schedule";
			String textEUROMODtable =
					"<html><h2 style=\"text-align: center; font-size:120%;\">Select EUROMOD policies to use in simulation by entering a valid 'policy start year' and 'policy system year'</h2>" +
							"<p style=\"text-align:center; font-size:120%;\">Policies for which no start year is provided will be omitted from the simulation.<br />" +
							"<p style=\"text-align:center; font-size:120%;\">Policy system year must match the year selected in EUROMOD / UKMOD when creating the policy.<br />" +
							"If no policy is selected for the start year of the simulation (<b>" + startYear + "</b>), then the earliest policy will be applied.<br />" +
							"<b>Optional</b>: add a description of the scenario policy to record what the policy refers to.</p>";
			ScenarioTable tableEUROMODscenarios = new ScenarioTable(textEUROMODtable, columnNames, data);

			FormattedDialogBoxNonStatic policyScheduleBox = new FormattedDialogBoxNonStatic(
					titleEUROMODtable,
					null,
					900,
					300 + euromodOutputTextFiles.size() * 11,
					tableEUROMODscenarios,
					true
			);

			// Store a copy in the country-specific input directory
			XLSXfileWriter.createXLSX(
					countryInputPath,
					Parameters.EUROMODpolicyScheduleFilename,
					country.toString(),
					columnNames,
					data
			);

			if (choices[0] || choices[2] || choices[3] || choices[4]) {
				TaxDonorDataParser.constructAggregateTaxDonorPopulationCSVfile(country, showGui);
				if (Parameters.trainingFlag) {
					TaxDonorParserTraining.databaseFromCSV(country, startYear, true);
				} else {
					TaxDonorDataParser.databaseFromCSV(country, startYear, true);
				}
				Parameters.loadTimeSeriesFactorForTaxDonor(country);
                Parameters.defineCountryString(country);
				TaxDonorDataParser.populateDonorTaxUnitTables(country, showGui);
			}
		}
	}

	/**
	 * METHOD FOR DISPLAYING GUI FOR SELECTING COUNTRY AND START YEAR OF SIMULATION
	 */
	private static void chooseCountryAndStartYear() {

		ComboBoxCountry cbCountry = new ComboBoxCountry(null);
		ComboBoxYear cbStartYear = new ComboBoxYear(null);

		JInternalFrame countryAndYearFrame = new JInternalFrame();
		BasicInternalFrameUI bi = (BasicInternalFrameUI)countryAndYearFrame.getUI();
		bi.setNorthPane(null);
		countryAndYearFrame.setBorder(null);
		cbCountry.setBorder(BorderFactory.createTitledBorder("Country selection drop-down menu"));
		cbStartYear.setBorder(BorderFactory.createTitledBorder("Start year selection drop-down menu"));
		countryAndYearFrame.setLayout(new BoxLayout(countryAndYearFrame.getContentPane(), BoxLayout.PAGE_AXIS));
		countryAndYearFrame.add(cbCountry);
		countryAndYearFrame.add(new JPanel());
		countryAndYearFrame.add(cbStartYear);
		countryAndYearFrame.add(new JPanel());
		countryAndYearFrame.setVisible(true);

		String title = "Country and Start Year";
		String text = "<html><h2 style=\"text-align: center; font-size:120%;\">Select simulation country and start year</h2>";

		int height = 350, width = 600;
		Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
		if (screenSize.width < 850) {
			width = (int) (screenSize.width * 0.95);
		}

		FormattedDialogBox.create(title, text, width, height, countryAndYearFrame, true, true, true);

		country = cbCountry.getCountryEnum();
		startYear = cbStartYear.getYear();
		writeSelectedCountryAndYear();

	}
}
