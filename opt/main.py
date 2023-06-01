# Import required Python system libraries.
from pathlib import Path
from argparse import ArgumentParser

def __main(path_root):

    # Parse the program's input arguments.
    args = __parse_arguments(path_root)

    # Run the optimisation routine.
    import peak_model
    peak_model.solve(args)

def __parse_arguments(path_root):
   
    # Construct parser and collect the arguments.
    parser = __construct_parser(path_root)
    args = parser.parse_args()

    # Check that the arguments point to actual CSVs.
    __exists(parser, args.load, "Base load forecast", ".csv")
    __exists(parser, args.solar, "Solar PV forecast", ".csv")
    __exists(parser, args.battery, "Battery specifications", ".csv")
    __exists(parser, args.config, "Configuration", ".json")

    return args
 
def __construct_parser(path_root):
    """
    Construct a program argument parser that outputs human-readable descriptions of the
    required and optional arguments to run the program.
    """

    parser = ArgumentParser(description='Optimizes the battery schedules for a given load and PV forecast.')

    # Default values.
    path_conf_json = path_root / 'default_config.json'
    path_out_csv = Path.cwd() / 'schedule.csv'

    parser.add_argument('load', metavar='<load>.csv',
                        help='Base load forecast path to data (in *.csv format).')
    parser.add_argument('solar', metavar='<solar>.csv',
                        help='Solar PV forecast path to data (in *.csv format).')
    parser.add_argument('battery', metavar='<batt>.csv',
                        help="Battery specifications path to data (in *.csv format)")

    parser.add_argument('--config', metavar='<config>.json', default=str(path_conf_json),
                        help="Solver configuration (in *.json format), default: %(default)s)")
    parser.add_argument('-o', '--out', metavar='<sched>.csv', default=str(path_out_csv),
                        help="Battery schedule output file, default: ./schedule.csv")
    parser.add_argument('-v', '--verbose', action='store_true',
                        help="Print log to console instead of to file.")
    parser.add_argument('-c', '--cleanup', action='store_true',
                        help="Remove created temporary files on shutdown.")

    return parser

def __exists(parser, str_file, label, expect_suffix):
    path_file = Path(str_file)
    if not path_file.exists():
        parser.error(f"{label} file not found in '{str_file}'")
    if not path_file.suffix == expect_suffix:
        parser.error(f"Path '{str_file}' not a {expect_suffix} file.")

# Single function entry point, with the script's root.
if __name__ == '__main__':
    __main(Path(__file__).resolve().parent)
