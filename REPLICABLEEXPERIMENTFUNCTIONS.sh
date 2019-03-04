#!/bin/bash

function lock_destination_directory()
{
    if [ ! -z "${DESTINATIONDIRECTORY}" ]
    then
        if [ -d "${DESTINATIONDIRECTORY}" ]
        then
            if chmod -R +rx "${DESTINATIONDIRECTORY}"
            then
                echo "Destination directory is locked."
            else
                echo "Error: failed to lock destination directory because chmod failed."
            fi
            
        else
            echo "Error: failed to lock destination directory because directory could not be found."
        fi
    else
        echo "Error: failed to lock destination directory because BASH variable is null."
    fi
    
}

function enter_debug_mode()
{
    echo "Current mode: Debug"
    echo "Debugging Mode" > "MODE.txt"
    if [ ! -z "${DEBUGDIRECTORY}" ] && [ "" != "${DEBUGDIRECTORY}" ]
    then
       echo "${DEBUGDIRECTORY}" > "DESTINATION.txt"
    fi
}

function gracefully_exit_with_lock()
{
    cd "${CURRENTDIRECTORY}"
    export REPLICABLE=1
    enter_debug_mode
    lock_destination_directory

    exit 1
}

function graceful_exit()
{
    cd "${CURRENTDIRECTORY}"
    export REPLICABLE=1
    enter_debug_mode
    exit 1
}

function exit_if_directory_not_clean()
{
    if [ "$#" -gt 0 ]
    then
        if [ -d "$1" ]
        then
            cd "$1"
        else
            echo "Error: failed to change directory to $1."
            graceful_exit
        fi
    fi

    if local TEMPVAR="$(git status --porcelain)"
    then
        :
    else
        echo "Error: git status command failed in $(pwd)!"
        graceful_exit
    fi
    if [ -z "${TEMPVAR}" ]
    then
        :
    else
        echo "Error: directory is not clean. Use git status command for details."
        echo "Directory: $(pwd)"
        
        graceful_exit
    fi
    cd "${CURRENTDIRECTORY}"
}

function clean_repositories_check()
{
    read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
    if [ -z "${REPLICABLEEXPERIMENTDIRECTORY}" ] || [ "" = "${REPLICABLEEXPERIMENTDIRECTORY}" ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        graceful_exit
    fi
    exit_if_directory_not_clean "${REPLICABLEEXPERIMENTDIRECTORY}"
    exit_if_directory_not_clean "${CURRENTDIRECTORY}"
}

function get_destination_info()
{
    while :
    do
        read TEMPVAR
        if [ "${TEMPVAR}" != "Debug directory:" ]
        then
            echo "First line of PATHS.txt should be Debug directory:"
            graceful_exit
        fi
        read DEBUGDIRECTORY
        read TEMPVAR
        if [ "${TEMPVAR}" != "Penultimate directory:" ]
        then
            echo "Third line of PATHS.txt should be Penultimate directory:"
            graceful_exit 
        fi
        read REPLICABLEDIRECTORY
        read TEMPVAR
        if [ "${TEMPVAR}" != "SHA1:" ]
        then
            echo "Fifth line of PATHS.txt should be SHA1:"
            graceful_exit
        fi
        read SHA1HASH
        break
    done < "PATHS.txt"
    export REPLICABLEDIRECTORY
    export DEBUGDIRECTORY
    export SHA1HASH
}

function build_destination_string()
{
    if [ "${REPLICABLEDIRECTORY: -1}" = "/" ]
    then
        export DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}${SHA1}"
    else
        export DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}/${SHA1}"
    fi
}

function write_destination_info()
{
    echo "Debug directory:" > "PATHS.txt"
    echo "${DEBUGDIRECTORY}" >> "PATHS.txt"
    echo "Penultimate directory:" >> "PATHS.txt"
    echo "${REPLICABLEDIRECTORY}" >> "PATHS.txt"
    echo "SHA1:" >> "PATHS.txt"
    SHA1="$(git rev-parse --short HEAD)"
    echo "${SHA1}" >> "PATHS.txt"

    build_destination_string

    if [ ! -d "${DESTINATIONDIRECTORY}" ]
    then
        if mkdir ${DESTINATIONDIRECTORY}
        then
            :
        else
            echo "Creation of directory with path ${DESTINATIONDIRECTORY} failed!"
            graceful_exit
        fi
    fi

    echo "${DESTINATIONDIRECTORY}" > "DESTINATION.txt"
    export DESTINATIONDIRECTORY
}

function write_to_diary()
{
    cd "${REPLICABLEEXPERIMENTDIRECTORY}"
    REPLICABLEEXPERIMENTSHA1="$(git rev-parse --short HEAD)"
    cd "${CURRENTDIRECTORY}"
    if chmod -R +rwx "${DESTINATIONDIRECTORY}" # graceful exits after this command should include lock
    then
        echo "Destination directory is unlocked."
        echo "$1 ${REPLICABLEEXPERIMENTSHA1}" >> "${DESTINATIONDIRECTORY}/DIARY.txt"
    else
        echo "Failed to unlock destination directory."
    fi
    
    
}

function setup_replicable_experiment()
{
    CURRENTDIRECTORY=$(pwd)
    clean_repositories_check
    get_destination_info
    REPLICABLE=0
    echo "Current mode: Replicable"
    echo "Replicable Mode" > "MODE.txt"
    write_destination_info 
    write_to_diary "$1" # graceful exits after this command should include lock.
    lock_destination_directory
    return 0
}



function setup_replicable_experiment_script()
{
    # Check whether in DEBUG mode or REPLICABLE mode.
    read REPLICABLESTR < "MODE.txt"
    if [ -z "${REPLICABLESTR}" ] || [ "${REPLICABLESTR}" != "Replicable Mode" ]
    then
        echo "Executing $1 in DEBUG mode."
        return 0
    fi

    export REPLICABLE=0
    CURRENTDIRECTORY=$(pwd)
    clean_repositories_check
    get_destination_info


    # Check that PATHS.txt SHA1 matches current SHA1 hash:
    SHA1="$(git rev-parse --short HEAD)"
    if [ "${SHA1}" != "${SHA1HASH}" ]
    then
        echo "Error: SHA1HASH in PATHS.txt does not match current SHA1 commit ID."
        graceful_exit
    fi

    # Verify destination directory from PATHS.txt and DESTINATION.txt are the same.
    build_destination_string
    read DESTINATIONFROMFILE < "DESTINATION.txt"
    if [ -z "${DESTINATIONFROMFILE}" ] || [ "" = "${DESTINATIONFROMFILE}" ]
    then
       echo "Error: unable to read DESTINATION.txt."
       graceful_exit
    fi
    if [ ! "${DESTINATIONDIRECTORY}/" = "${DESTINATIONFROMFILE}" ] && [ ! "${DESTINATIONDIRECTORY}" = "${DESTINATIONFROMFILE}" ] && [ ! "${DESTINATIONDIRECTORY}" = "${DESTINATIONFROMFILE}/" ]
    then
        echo "Error: destinations from DESTINATION.txt and PATHS.txt do not match."
        graceful_exit 1
    fi

    write_to_diary "$1"
    export DESTINATIONDIRECTORY
    echo "Executing $1 in REPLICABLE mode."
    return 0
}

function gracefully_exit_successful_replicable_experiment_script()
{
   if [ ! -z "${REPLICABLE}" ] && [ "${REPLICABLE}" -eq "0" ]
   then
       lock_destination_directory
   fi
   exit 0
}

function replicable_experiment_cleanup()
{
    CURRENTDIRECTORY="$(pwd)"
    get_destination_info
    SHA1="$(git rev-parse --short HEAD)"
    build_destination_string
    
    read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
    if [ -z "${REPLICABLEEXPERIMENTDIRECTORY}" ] || [ "" = "${REPLICABLEEXPERIMENTDIRECTORY}" ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        graceful_exit
    fi
    
    write_to_diary "$1"
    lock_destination_directory
    enter_debug_mode
    return 0
}
