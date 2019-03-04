#!/bin/bash




function gracefully_exit_setup()
{
    cd "${CURRENTDIRECTORY}"
    if [ "$1" -eq "0" ]
    then
        :
    else
        if [ ! -z "${REPLICABLE}" ] && [ "${REPLICABLE}" -eq "0" ]
        then
            export REPLICABLE=1
            echo "Current mode: Debug"
            echo "Debugging Mode" > "MODE.txt"
            if [ ! -z "${REVERTDESTINATIONINFO}" ] && [ "${REVERTDESTINATIONINFO}" -eq "0" ]
            then
            
                if echo "${DEBUGDIRECTORY}" > "DESTINATION.txt"
                then
                    export REVERTDESTINATIONINFO=1
                fi
            fi

        fi
    fi
    if [ ! -z "${DESTINATIONDIRECTORY}" ]
    then
        if [ -d "${DESTINATIONDIRECTORY}" ]
        then
            chmod -R +rx "${DESTINATIONDIRECTORY}"
        fi
    fi

    exit 1
}
function gracefully_exit_failed_replicable_experiment_script()
{
    export REPLICABLE=1
    echo "Current mode: DEBUG"
    echo "Debugging Mode" > "MODE.txt"
        
    if echo "${DEBUGDIRECTORY}" > "DESTINATION.txt"
    then
        export REVERTDESTINATIONINFO=1
    fi
    
    if [ ! -z "${DESTINATIONDIRECTORY}" ]
    then
        if [ -d "${DESTINATIONDIRECTORY}" ]
        then
            chmod -R +rx "${DESTINATIONDIRECTORY}"
        fi
    fi

    exit 1
}



function graceful_exit()
{
    if [ "$1" -eq "0" ]
    then
        gracefully_exit_setup
    else
        gracefully_exit_failed_replicable_experiment_script
    fi
}

function exit_if_directory_not_clean()
{
    if [ "$#" -gt 1 ]
    then
        if [ -d "$2" ]
        then
            cd "$2"
        else
            echo "Error: failed to change directory to $2."
            graceful_exit $1
        fi
    fi
    if local TEMPVAR="$(git status --porcelain)"
    then
        :
    else
        echo "Error: git status command failed in $(pwd)!"
        
        graceful_exit $1
    fi
    if [ -z "${TEMPVAR}" ]
    then
        :
    else
        echo "Error: directory is not clean. Use git status command for details."
        echo "Directory: $(pwd)"
        
        graceful_exit $1
    fi
    cd "${CURRENTDIRECTORY}"
}

function get_destination_info()
{
    # Additional use of variables could consolidate PATHS.txt file requirements (currently spread across get_destination_info() and write_destination_info() )
    while :
    do
        read TEMPVAR
        if [ "${TEMPVAR}" != "Debug directory:" ]
        then
            echo "First line of PATHS.txt should be Debug directory:"
            graceful_exit $1
        fi
        read DEBUGDIRECTORY
        read TEMPVAR
        if [ "${TEMPVAR}" != "Penultimate directory:" ]
        then
            echo "Third line of PATHS.txt should be Penultimate directory:"
            graceful_exit $1
        fi
        read REPLICABLEDIRECTORY
        read TEMPVAR
        if [ "${TEMPVAR}" != "SHA1:" ]
        then
            echo "Fifth line of PATHS.txt should be SHA1:"
            graceful_exit $1
        fi
        read SHA1HASH
        break
    done < "PATHS.txt"
    export REPLICABLEDIRECTORY
    export DEBUGDIRECTORY
    export SHA1HASH
}

function write_destination_info()
{
    if [ "${REPLICABLEDIRECTORY: -1}" = "/" ]
    then
        export DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}${SHA1HASH}"
    else
        export DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}/${SHA1HASH}"
    fi

    if [ ! -d "${DESTINATIONDIRECTORY}" ]
    then
        if mkdir ${DESTINATIONDIRECTORY}
        then
            :
        else
            echo "Creation of directory with path ${DESTINATIONDIRECTORY} failed!"
            gracefully_exit_setup
        fi
    fi
    chmod -R +rwx "${DESTINATIONDIRECTORY}"
    export REVERTDESTINATIONINFO=0
    echo "Debug directory:" > "PATHS.txt"
    echo "${DEBUGDIRECTORY}" >> "PATHS.txt"
    echo "Penultimate directory:" >> "PATHS.txt"
    echo "${REPLICABLEDIRECTORY}" >> "PATHS.txt"
    echo "SHA1:" >> "PATHS.txt"
    SHA1="$(git rev-parse --short HEAD)"
    echo "${SHA1}" >> "PATHS.txt"
    echo "${DESTINATIONDIRECTORY}" > "DESTINATION.txt"
}


function setup_replicable_experiment()
{
    CURRENTDIRECTORY=$(pwd)
    read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
    if [ -z ${REPLICABLEEXPERIMENTDIRECTORY} ] || [ "" = ${REPLICABLEEXPERIMENTDIRECTORY}} ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        gracefully_exit_setup
    fi
    exit_if_directory_not_clean "0" "${REPLICABLEEXPERIMENTDIRECTORY}"
    exit_if_directory_not_clean "0" "${CURRENTDIRECTORY}"
    get_destination_info 1
    REPLICABLE=0
    echo "Current mode: Replicable"
    echo "Replicable Mode" > "MODE.txt"
    write_destination_info 1
    cd "${REPLICABLEEXPERIMENTDIRECTORY}"
    REPLICABLEEXPERIMENTSHA1="$(git rev-parse --short HEAD)"
    cd "${CURRENTDIRECTORY}"
    echo "$1 ${REPLICABLEEXPERIMENTSHA1}" >> "${DESTINATIONDIRECTORY}/DIARY.txt"
    chmod -R +rx "${DESTINATIONDIRECTORY}"
    return 0
}




function setup_replicable_experiment_script()
{
    read REPLICABLESTR < "MODE.txt"
    if [ -z "${REPLICABLESTR}" ] || [ "${REPLICABLESTR}" != "Replicable Mode" ]
    then
        echo "Executing $1 in DEBUG mode."
        return 0
    fi
    export REPLICABLE=0
    CURRENTDIRECTORY=$(pwd)
    read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
    if [ -z "${REPLICABLEEXPERIMENTDIRECTORY}" ] || [ "" = "${REPLICABLEEXPERIMENTDIRECTORY}" ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        graceful_exit 1
    fi
    exit_if_directory_not_clean "1" "${REPLICABLEEXPERIMENTDIRECTORY}"
    exit_if_directory_not_clean "1" "${CURRENTDIRECTORY}"
    get_destination_info
    if [ "${REPLICABLEDIRECTORY: -1}" = "/" ]
    then
        DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}${SHA1HASH}"
    else
        DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}/${SHA1HASH}"
    fi
    read DESTINATIONFROMFILE < "DESTINATION.txt"
    if [ -z "${DESTINATIONFROMFILE}" ] || [ "" = "${DESTINATIONFROMFILE}" ]
    then
       echo "Error: unable to read DESTINATION.txt."
       graceful_exit 1
    fi

    if [ ! "${DESTINATIONDIRECTORY}/" = "${DESTINATIONFROMFILE}" ] && [ ! "${DESTINATIONDIRECTORY}" = "${DESTINATIONFROMFILE}" ] && [ ! "${DESTINATIONDIRECTORY}" = "${DESTINATIONFROMFILE}/" ]
    then
        echo "Error: destinations from DESTINATION.txt and PATHS.txt do not match."
        graceful_exit 1
    fi
    cd "${REPLICABLEEXPERIMENTDIRECTORY}"
    REPLICABLEEXPERIMENTSHA1="$(git rev-parse --short HEAD)"
    cd "${CURRENTDIRECTORY}"
    chmod -R +rwx "${DESTINATIONDIRECTORY}"
    echo "$1 ${REPLICABLEEXPERIMENTSHA1}" >> "${DESTINATIONDIRECTORY}/DIARY.txt"
    export DESTINATIONDIRECTORY
    return 0
}

function gracefully_exit_successful_replicable_experiment_script()
{
   if [ ! -z "${REPLICABLE}" ] && [ "${REPLICABLE}" -eq "0" ]
   then
       chmod -R +rx "${DESTINATIONDIRECTORY}"
   fi
   exit 0
}

function replicable_experiment_cleanup()
{
    export REPLICABLE=1
    echo "Debugging Mode" > "MODE.txt"
    CURRENTDIRECTORY=$(pwd)
    read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt"
    if [ -z "${REPLICABLEEXPERIMENTDIRECTORY}" ] || [ "" = "${REPLICABLEEXPERIMENTDIRECTORY}" ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        graceful_exit 1
    fi
    get_destination_info 1
    if [ "${REPLICABLEDIRECTORY: -1}" = "/" ]
    then
        DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}${SHA1HASH}"
    else
        DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}/${SHA1HASH}"
    fi
    if echo "${DEBUGDIRECTORY}" > "DESTINATION.txt"
    then
        export REVERTDESTINATIONINFO=1
    fi
    cd "${REPLICABLEEXPERIMENTDIRECTORY}"
    REPLICABLEEXPERIMENTSHA1="$(git rev-parse --short HEAD)"
    cd "${CURRENTDIRECTORY}"
    chmod -R +rwx "${DESTINATIONDIRECTORY}"
    echo "$1 ${REPLICABLEEXPERIMENTSHA1}" >> "${DESTINATIONDIRECTORY}/DIARY.txt"
    chmod -R +rx "${DESTINATIONDIRECTORY}"
    return 0
}
