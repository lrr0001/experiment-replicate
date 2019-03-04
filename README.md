# replicable-experiment
This repository contains code to tie experiment results to the commit ID of the code that produced them.

Experiment code should be kept in a separate repository. The gitignore file for that repository should probably contain all files listed below, since one would expect them to be different for different computers. PATHS.txt and DESTINATION.txt will be changed by the code when switching between Debug mode and Replicable mode. If those two files are not included in gitignore, the code will not run, due to detection of unstaged changes.

The experiment repository should contain:
    PATHS.txt with contents:
Debug directory:
<path to debugging folder>
Penultimate directory:
<path to folder in which results directories will be stored>
SHA1:
<This line may be left blank. replicable-experiment will store the short SHA1 commit identification number of the experiment repository here.>
    DESTINATION.txt with contents:
<path to debugging folder>
    REPLICABLE-EXPERIMENT.txt
<path to replicable-experiment repository (the repository containing this README.md)>

Also included should be BASH scripts following a particular format:
    Setup script
read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
./"${REPLICABLEEXPERIMENTDIRECTORY}/REPLICABLEEXPERIMENTFUNCTIONS.sh"
setup_replicable_experiment $(basename -- "$0")

    Experiment scripts
read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
./"${REPLICABLEEXPERIMENTDIRECTORY}/REPLICABLEEXPERIMENTFUNCTIONS.sh"
setup_replicable_experiment_script $(basename -- "$0")

<...>

if [! <code that might fail> ]
then
    echo "Error: code failed to run!"
    graceful_exit 1
fi

<...>

gracefully_exit_successful_replicable_experiment_script

    cleanup script
read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
./"${REPLICABLEEXPERIMENTDIRECTORY}/REPLICABLEEXPERIMENTFUNCTIONS.sh"
replicable_experiment_cleanup $(basename -- "$0")
