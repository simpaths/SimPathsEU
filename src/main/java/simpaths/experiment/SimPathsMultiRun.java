// define package
package simpaths.experiment;

// import Java packages
import microsim.data.db.DatabaseUtils;
import microsim.data.db.Experiment;
import org.apache.commons.io.FileUtils;
import org.apache.log4j.Level;
import org.apache.commons.cli.*;
import org.yaml.snakeyaml.Yaml;
import simpaths.model.enums.ConfigEnumValue;
import simpaths.model.enums.MacroLogLevel;
import simpaths.model.enums.MacroModelMode;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.Map;

import simpaths.data.Parameters;
import simpaths.model.SimPathsModel;
import microsim.data.MultiKeyCoefficientMap;
import microsim.data.excel.ExcelAssistant;
import microsim.engine.MultiRun;
import microsim.engine.SimulationEngine;
import microsim.gui.shell.MultiRunFrame;
import simpaths.model.enums.Country;

// Logging and file writing
import org.apache.log4j.FileAppender;
import org.apache.log4j.Logger;
import org.apache.log4j.PatternLayout;
import java.io.*;
import java.text.SimpleDateFormat;
import java.util.Date;
import microsim.data.ExperimentManager;


public class SimPathsMultiRun extends MultiRun {

	// command line args
	private static String countryString;
	private static Integer popSize = 25000;
	private static int startYear;
	private static int endYear = 2020;
	private static int maxNumberOfRuns = 25;
	private static Long randomSeed = 615L;
	public static boolean executeWithGui = true;

	// innovation args
	private static boolean randomSeedInnov = true;
	private static boolean intertemporalElasticityInnov = false;
	private static boolean labourSupplyElasticityInnov = false;
	private static boolean flagDatabaseSetup = false;

	// integration-test flag: when true, redirects simulation output into a fixed
	// INTEGRATION_TESTS folder so regression tests can locate and diff the results.
	// Intentionally does NOT flip the training-data flag (unlike the UK port) —
	// EU runs the integration test against real input data until a training set exists.
	private static boolean integrationTest = false;

	// passing args for config file
	private static Map<String, Object> modelArgs;
	private static Map<String, Object> innovationArgs;
	private static Map<String, Object> collectorArgs;
	private static Map<String, Object> parameterArgs;
	public static String configFile = "default.yml";

	// other working variables
	private static Country country;
	private static double interestRateInnov = 0.0;
	private static double disposableIncomeFromLabourInnov = 0.0;
	private static boolean outputToFile = false;
	private Long counter = 0L;
	public static Logger log = Logger.getLogger(SimPathsMultiRun.class);

	/**
	 *
	 * 	MAIN PROGRAM ENTRY FOR MULTI-SIMULATION
	 *
	 */
	public static void main(String[] args) {

		// set default values for country and start year
		MultiKeyCoefficientMap lastDatabaseCountryAndYear = ExcelAssistant.loadCoefficientMap("input" + File.separator + Parameters.DatabaseCountryYearFilename + ".xlsx", "Data", 1);
		if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[EL]"))) {
			countryString = "Greece";
		} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[HU]"))) {
			countryString = "Hungary";
		} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[IT]"))) {
			countryString = "Italy";
		} else if (lastDatabaseCountryAndYear.keySet().stream().anyMatch(key -> key.toString().equals("MultiKey[PL]"))) {
			countryString = "Poland";
		} else {
			throw new IllegalArgumentException(
					"Country not recognised. Restart the simulation and choose one of the available countries (EL, HU, IT, PL)."
			);
		}


		country = Country.getCountryFromNameString(countryString);
		String valueYear = lastDatabaseCountryAndYear.getValue(country.toString()).toString();
		startYear = Integer.parseInt(valueYear);

		// process Yaml config file
		if (!parseYamlConfig(args)) {
			// if parseYamlConfig returns false (indicating bad filename passed), exit main
			return;
		}
		if (innovationArgs!=null)
			updateLocalParameters(innovationArgs);
		if (parameterArgs != null)
			updateParameters(parameterArgs);

		// Parse command line arguments to override defaults
		if (!parseCommandLineArgs(args)) {
			// If parseCommandLineArgs returns false (indicating help option is provided), exit main
			return;
		}
		country = Country.getCountryFromNameString(countryString);

		// Propagate the resolved country into the static Parameters.COUNTRY_STRING used by
		// country-specific lookups (e.g. Parameters.getStatePensionAge). SimPathsStart does
		// this implicitly via runGUIlessSetup(), but SimPathsMultiRun jumps straight into
		// Parameters.databaseSetup on -DBSetup and into model construction otherwise, so
		// without this call the DBSetup branch crashes with "No PSA rules for country=".
		Parameters.defineCountryString(country);

        /*comment these lines if input folder needs to be saved in output*/
        // Disable copying input folders into output
        ExperimentManager.getInstance().copyInputFolderStructure = false;
        // Ensure database files are loaded from the correct input directory
        DatabaseUtils.databaseInputUrl = Experiment.inputFolder + File.separator + "input";

		if (flagDatabaseSetup) {
			// Define country string before database setup
			Parameters.defineCountryString(country);
			Parameters.databaseSetup(country, executeWithGui, startYear);
		} else {
			// standard simulation

			log.info("Starting run with seed = " + randomSeed);

			// Set up file logging early (before engine.setup) so logs directory is created
			// in the same timestamped folder that will be used for CSV output
			if (outputToFile) {
				setupFileLogging(randomSeed);
			}

			SimulationEngine engine = SimulationEngine.getInstance();

			SimPathsMultiRun experimentBuilder = new SimPathsMultiRun();
			engine.setExperimentBuilder(experimentBuilder);
			engine.setup();		//This is needed to update model attributes (from model_args in config file)

			if (integrationTest) {
				// Redirect all output into a fixed, well-known folder so the
				// integration test can locate results deterministically. The folder
				// name depends on Parameters.trainingFlag (set from parameter_args
				// in YAML before this block runs) so the real-data and training-data
				// baselines never collide.
				String integrationSubFolder = Parameters.trainingFlag
						? "INTEGRATION_TESTS_TRAINING"
						: "INTEGRATION_TESTS";
				String integrationOutputFolder = "." + File.separator + "output"
						+ File.separator + integrationSubFolder;
				Experiment.testOutputFolder = integrationOutputFolder;

				try {
					File folder = new File(integrationOutputFolder);
					if (FileUtils.isDirectory(folder)) {
						FileUtils.deleteDirectory(folder);
					}
				} catch (IOException e) {
					throw new RuntimeException(e);
				}
			}

			if (executeWithGui)
				new MultiRunFrame(experimentBuilder, "SimPaths MultiRun", maxNumberOfRuns);
			else
				experimentBuilder.start();
		}
	}

	private static boolean parseCommandLineArgs(String[] args) {

		Options options = new Options();

		Option popSizeOption = new Option("p", "popSize", true, "Population size");
		popSizeOption.setArgName("int");
		options.addOption(popSizeOption);

		Option startYearOption = new Option("s", "startYear", true, "Start year");
		startYearOption.setArgName("year");
		options.addOption(startYearOption);

		Option endYearOption = new Option("e", "endYear",true, "End year");
		endYearOption.setArgName("year");
		options.addOption(endYearOption);

		Option setupOption = new Option("DBSetup", "Setup only");
		options.addOption(setupOption);

		Option maxRunsOption = new Option("n", "maxNumberOfRuns", true, "Maximum number of runs");
		maxRunsOption.setArgName("int");
		options.addOption(maxRunsOption);

		Option seedOption = new Option("r", "randomSeed", true, "Random seed");
		seedOption.setArgName("int");
		options.addOption(seedOption);

		Option guiOption = new Option("g", "executeWithGui", true, "Show GUI");
		guiOption.setArgName("true/false");
		options.addOption(guiOption);

		Option configOption = new Option("config", true, "Specify custom config file (default: default.yml)");
		configOption.setArgName("file");
		options.addOption(configOption);

		Option fileOption = new Option("f", "Output to file");
		options.addOption(fileOption);

		Option trainingOption = new Option("t", "training", true, "Use training data subset (InitialPopulations/training, EUROMODoutput/training, TaxDonorParserTraining). Overrides parameter_args.trainingFlag from YAML.");
		trainingOption.setArgName("true/false");
		options.addOption(trainingOption);

		// Macro module options
		Option macroOption = new Option("macro", "macroModel", true,
				"Macro layers to run: " + ConfigEnumValue.valueList(MacroModelMode.class));
		macroOption.setArgName(ConfigEnumValue.valueList(MacroModelMode.class));
		options.addOption(macroOption);

		Option macroLogOption = new Option("macroLog", "macroLogging", true,
				"Macro logging verbosity: " + ConfigEnumValue.valueList(MacroLogLevel.class));
		macroLogOption.setArgName(ConfigEnumValue.valueList(MacroLogLevel.class));
		options.addOption(macroLogOption);

		Option helpOption = new Option("h", "help", false, "Print this help message");
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
			if (cmd.hasOption("n")) {
				maxNumberOfRuns = Integer.parseInt(cmd.getOptionValue("n"));
			}

			if (cmd.hasOption("g")) {
				executeWithGui = Boolean.parseBoolean(cmd.getOptionValue("g"));
			}

			if (cmd.hasOption("r")) {
				randomSeed = Long.parseLong(cmd.getOptionValue("r"));
			}

			if (cmd.hasOption("s")) {
				startYear = Integer.parseInt(cmd.getOptionValue("s"));
			}

			if (cmd.hasOption("e")) {
				endYear = Integer.parseInt(cmd.getOptionValue("e"));
			}

			if (cmd.hasOption("DBSetup")) {
				flagDatabaseSetup = true;
			}

			if (cmd.hasOption("t")) {
				boolean trainingValue = Boolean.parseBoolean(cmd.getOptionValue("t"));
				Parameters.setTrainingFlag(trainingValue);
				System.out.println("Training-data flag set explicitly via CLI: -t " + trainingValue + " (overrides parameter_args.trainingFlag from YAML)");
			}

			if (cmd.hasOption("p")) {
				popSize = Integer.parseInt(cmd.getOptionValue("p"));
			}

			// Parse macro module options and add to modelArgs
			if (cmd.hasOption("macro")) {
				if (modelArgs == null) {
					modelArgs = new java.util.HashMap<>();
				}
				modelArgs.put("mm_macroModel", MacroModelMode.fromConfigValue(cmd.getOptionValue("macro")));
			}
			if (cmd.hasOption("macroLog")) {
				if (modelArgs == null) {
					modelArgs = new java.util.HashMap<>();
				}
				modelArgs.put("mm_macroLogging", MacroLogLevel.fromConfigValue(cmd.getOptionValue("macroLog")));
			}

			if (cmd.hasOption("f")) {
				outputToFile = true;
			}
		} catch (ParseException e) {
			System.err.println("Error parsing command line arguments: " + e.getMessage());
			formatter.printHelp("SimPathsMultiRun", options);
			return false;
		}

		return true;
	}

	private static void printHelpMessage(HelpFormatter formatter, Options options) {
		String header = "SimPathsMultiRun can run multiple sequential runs, " +
				"resetting the population to the start year and iterating from the start seed. " +
				"It takes the following options:";
		String footer = "When running with no display, `-g` must be set to `false`.";
		formatter.printHelp("SimPathsMultiRun", header, options, footer, true);
	}

	private static boolean parseYamlConfig(String[] args) {

		boolean customConfig = false;

		// Check if an alternative config file is specified in the command line
		for (int i = 0; i < args.length - 1; i++) {
			if (args[i].equals("-config")) {
				configFile = args[i + 1];
				customConfig = true;
				break;
			}
		}

		// Parse YAML config file and update parameters
		try {
			Yaml yaml = new Yaml();
			String configFilePath = "config" + File.separator + configFile;
			FileInputStream inputStream = new FileInputStream(configFilePath);
			Map<String, Object> config = yaml.load(inputStream);

			// Update parameters from the config file
			for (Map.Entry<String, Object> entry : config.entrySet()) {
				String key = entry.getKey();
				Object value = entry.getValue();

				if ("model_args".equals(key)) {
					modelArgs = (Map<String, Object>) value;
					continue;
				}

				if ("innovation_args".equals(key)) {
					innovationArgs = (Map<String, Object>) value;
					continue;
				}

				if ("collector_args".equals(key)) {
					collectorArgs = (Map<String, Object>) value;
					continue;
				}

				if ("parameter_args".equals(key)) {
					parameterArgs = (Map<String, Object>) value;
					continue;
				}

				// Use reflection to dynamically set the field based on the key
				updateLocalParameters(key, value);
			}

		} catch (FileNotFoundException e) {
			// Config file specified but not found, continue with defaults
			if (customConfig) {
				System.err.println("Config file " + configFile + " not found; please supply a valid config file.");
				return false;
			}
		}
		return true;
	}

	public static void updateLocalParameters(String key, Object value) {
		try {
			Field field = SimPathsMultiRun.class.getDeclaredField(key);
			field.setAccessible(true);

			// Determine the field type
			Class<?> fieldType = field.getType();

			// Convert the YAML value to the field type
			Object convertedValue = convertToType(value, fieldType);

			// Set the field value
			field.set(null, convertedValue);

			field.setAccessible(false);
		} catch (NoSuchFieldException | IllegalAccessException e) {
			// Handle exceptions if the field is not found or inaccessible
			e.printStackTrace();
		}
	}

	public static void updateLocalParameters(Map<String, Object> args) {

		for (Map.Entry<String, Object> entry : args.entrySet()) {
			updateLocalParameters(entry.getKey(), entry.getValue());
		}
	}

	/**
	 * Update static fields on {@link simpaths.data.Parameters} from a YAML
	 * {@code parameter_args:} block. Mirrors UK's mechanism but without UK's
	 * directory-shuffling special cases (those setters don't all exist in EU).
	 * Unknown keys produce a NoSuchFieldException stacktrace — same failure
	 * mode as the other {@code updateLocalParameters} overloads.
	 */
	public static void updateParameters(Map<String, Object> parameter_args) {

		for (Map.Entry<String, Object> entry : parameter_args.entrySet()) {
			String key = entry.getKey();
			Object value = entry.getValue();

			try {
				Field field = Parameters.class.getDeclaredField(key);
				field.setAccessible(true);

				Class<?> fieldType = field.getType();
				Object convertedValue = convertToType(value, fieldType);

				field.set(null, convertedValue);
				field.setAccessible(false);
			} catch (NoSuchFieldException | IllegalAccessException e) {
				e.printStackTrace();
			}
		}
	}

	public static void updateParameters(Object object, Map<String, Object> args) {

		for (Map.Entry<String, Object> entry : args.entrySet()) {
			String key = entry.getKey();
			Object value = entry.getValue();

			try {
				Field field = object.getClass().getDeclaredField(key);
				field.setAccessible(true);

				// Determine the field type
				Class<?> fieldType = field.getType();

				// Convert the YAML value to the field type
				Object convertedValue = convertToType(value, fieldType);

				// Set the field value
				field.set(object, convertedValue);

				field.setAccessible(false);
			} catch (NoSuchFieldException | IllegalAccessException e) {
				// Handle exceptions if the field is not found or inaccessible
				e.printStackTrace();
			}
		}
	}

	@SuppressWarnings({"unchecked", "rawtypes"})
	private static Object parseConfigEnum(Class<?> targetType, Object value) {
		Class rawType = targetType;
		Enum[] constants = (Enum[]) targetType.getEnumConstants();
		Enum disabled = constants.length > 0 ? constants[0] : null;
		return ConfigEnumValue.parse(rawType, value, disabled, targetType.getSimpleName());
	}

	private static Object convertToType(Object value, Class<?> targetType) {
		// Convert the YAML value to the target type
		if (int.class.equals(targetType)) {
			return ((Number) value).intValue();
		} else if (Integer.class.equals(targetType)) {
			return Integer.parseInt(value.toString());
		} else if (long.class.equals(targetType) || Long.class.equals(targetType)) {
			return ((Number) value).longValue();
		} else if (boolean.class.equals(targetType) || Boolean.class.equals(targetType)) {
			return Boolean.parseBoolean(value.toString());
		} else if (double.class.equals(targetType)) {
			return ((Number) value).doubleValue();
		} else if (Double.class.equals(targetType)) {
			return Double.parseDouble(value.toString());
		} else if (targetType.isEnum()) {
			// SnakeYAML resolves YAML 1.1 booleans first, so an unquoted `off` arrives here as
			// Boolean.FALSE rather than "off"; ConfigEnumValue maps it to the disabled constant.
			return parseConfigEnum(targetType, value);
		} else {
			// If it's none of the known types, return the value as is
			return value;
		}
	}

	@Override
	public void buildExperiment(SimulationEngine engine) {

		SimPathsModel model = new SimPathsModel(Country.getCountryFromNameString(countryString), startYear);
		updateLocalParameters(model);
		if (modelArgs != null)
			updateParameters(model, modelArgs);

		engine.addSimulationManager(model);

		SimPathsCollector collector = new SimPathsCollector(model);
		if (collectorArgs != null)
			updateParameters(collector, collectorArgs);
		engine.addSimulationManager(collector);
		model.setCollector(collector);

	}

	private void updateLocalParameters(SimPathsModel model) {
		model.setEndYear(endYear);
		model.setFirstRun(counter == 0);
//		SimPathsModel model = new SimPathsModel();
		model.setPopSize(popSize);
		model.setRandomSeedIfFixed(randomSeed);
		model.setInterestRateInnov(interestRateInnov);
		model.setDisposableIncomeFromLabourInnov(disposableIncomeFromLabourInnov);
	}

	/**
	 * Set up file logging to a timestamped output folder.
	 * Creates a 'logs' subdirectory containing run_[seed].txt and run_[seed].log.
	 * 
	 * Also sets Experiment.testOutputFolder so that the database and CSV outputs
	 * use the same folder, avoiding multiple timestamped folders.
	 * 
	 * @param seed The random seed (used for folder naming and log file names)
	 */
	private static void setupFileLogging(Long seed) {
		try {
			// Generate timestamped folder path (same format as Experiment.initialiseOutputFolder())
			// Include run label suffix to match Experiment run-folder naming
			SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMddHHmmss");
			String timestamp = sdf.format(new Date());
			String runLabel = buildRunLabel(seed, 0L);
			// Use "./" prefix for H2 database compatibility (requires explicit relative or absolute path)
			String outputFolder = "." + File.separator + "output" + File.separator + timestamp + "_" + runLabel;
			
			// Set the shared output folder for all JAS-mine components (database, CSV, etc.)
			// This prevents multiple timestamped folders from being created
			Experiment.testOutputFolder = outputFolder;
			
			File logDir = new File(outputFolder + File.separator + "logs");
			if (!logDir.exists()) {
				logDir.mkdirs();
			}
			
			// Writing console outputs to run_[seed].txt
			System.setOut(new PrintStream(new BufferedOutputStream(
				new FileOutputStream(logDir.getPath() + File.separator + "run_" + seed + ".txt")), true));
			
			// Writing logs to run_[seed].log
			FileAppender appender = new FileAppender();
			appender.setName("Run logging " + seed);  // Unique name per run
			appender.setFile(logDir.getPath() + File.separator + "run_" + seed + ".log");
			appender.setAppend(false);
			appender.setLayout(new PatternLayout("%d{yyyy MMM dd HH:mm:ss} - %m%n"));
			appender.activateOptions();
			Logger.getRootLogger().setLevel(Level.DEBUG);
			Logger.getRootLogger().addAppender(appender);
			
			log.info("File logging enabled. Output folder: " + outputFolder);
		} catch (FileNotFoundException e) {
			System.err.println("Failed to set up file logging: " + e.getMessage());
			throw new RuntimeException(e);
		}
	}

	private void iterateParameters(Long counter) {

		if (randomSeedInnov) {
			randomSeed++;
			System.out.println("Random seed " + randomSeed);
		}
		if (intertemporalElasticityInnov) {
			if (counter==1)
				interestRateInnov = 0.0075;
			else if (counter==2)
				interestRateInnov = -0.0075;
		}
		if (labourSupplyElasticityInnov) {
			if (counter==1)
				disposableIncomeFromLabourInnov = 0.01;
			else if (counter==2)
				disposableIncomeFromLabourInnov = -0.01;
		}
	}
	
	@Override
	public boolean nextModel() {
		counter++;
		if (counter < maxNumberOfRuns) {
			iterateParameters(counter);
			return true;
		} else {
			return false;
		}
	}

	@Override
	public String setupRunLabel() {
		return buildRunLabel(randomSeed, counter);
	}

	private static String buildRunLabel(Long seed, Long runCounter) {
		StringBuilder label = new StringBuilder();
		label.append(seed).append("_").append(runCounter);

		String dsgeShock = extractScenarioNameWithoutCsv("mm_dsgeShockScenario");
		if (dsgeShock != null) {
			label.append("_").append(dsgeShock);
		}

		String ramseyScenario = extractScenarioNameWithoutCsv("mm_ramseyScenario");
		if (ramseyScenario != null) {
			label.append("_").append(ramseyScenario);
		}


		return label.toString();
	}

	private static String extractScenarioNameWithoutCsv(String key) {
		if (modelArgs == null) {
			return null;
		}

		Object raw = modelArgs.get(key);
		if (raw == null) {
			return null;
		}

		String value = raw.toString().trim();
		if (value.isEmpty()) {
			return null;
		}

		int slashIdx = Math.max(value.lastIndexOf('/'), value.lastIndexOf('\\'));
		String fileName = (slashIdx >= 0) ? value.substring(slashIdx + 1) : value;
		if (fileName.isEmpty()) {
			return null;
		}

		if (fileName.toLowerCase().endsWith(".csv")) {
			fileName = fileName.substring(0, fileName.length() - 4);
		}

		return fileName.isEmpty() ? null : fileName;
	}
}
