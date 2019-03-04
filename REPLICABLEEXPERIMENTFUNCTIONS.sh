#!/bin/bash




function gracefully_exit_setup()
{
    cd "${CURRENTDIRECTORY}"
    if [ "$1" -eq "0" ]
    then
        :
    else
        if [ {! -z "${REPLICABLE}"}&&{"${REPLICABLE}" -eq "0"} ]
        then
            export REPLICABLE=1
            echo "Current mode: Debug"
            if [ {! -z "${REVERTDESTINATIONINFO}"}&&{"${REVERTDESTINATIONINFO}" -eq "0"} ]
            then
            
                if echo "${DEBUGDIRECTORY}" > "DESTINATION.txt"
                then
                    export REVERTDESTINATIONINFO=1
                fi
            fi

        fi
    fi
    if [! -z "${DESTINATIONDIRECTORY}" ]
    then
        if [ ls "${DESTINATIONDIRECTORY}" 2>/dev/null]
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
    echo "${REPLICABLEDIRECTORY}"
    if [ "$(${REPLICABLEDIRECTORY}: -1)" = "/" ]
    then
        export DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}${SHA1}"
    else
        export DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}/${SHA1}"
    fi

    if [ ! -d "${DESTINATIONDIRECTORY}" ]
    then
        if [ ! mkdir ${DESTNATIONDIRECTORY} ]
        then
            echo "Creation of directory with path ${DESTINATIONDIRECTORY} failed!"
            gracefully_exit_setup
        fi
    fi
    chmod -R +rwx "${DESTINATIONDIRECTORY}"
    export REVERTDESTINATIONINFO=0
    echo "Debug directory:" > "PATHS.txt"
    echo "${DEBUGDICRECTORY}" >> "PATHS.txt"
    echo "Penultimate directory:" >> "PATHS.txt"
    echo "${REPLICABLEDIRECTORY}" >> "PATHS.txt"
    echo "SHA1:" >> "PATHS.txt"
    SHA1="$(git rev-parse --short HEAD)"
    echo "${SHA1}" >> "PATHS.txt"
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
    export REPLICABLE=0
    echo "Current mode: Replicable"
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
    if [ { -z "${REPLICABLE}"}||{"${REPLICABLE}" -ne "0"} ]
    then
        echo "Executing $1 in DEBUG mode."
        return 0
    fi
    CURRENTDIRECTORY=$(pwd)
    if [ ! read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt" ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        graceful_exit 1
    fi
    exit_if_directory_not_clean "1" "${REPLICABLEEXPERIMENTDIRECTORY}"
    exit_if_directory_not_clean "1" "${CURRENTDIRECTORY}"
    get_destination_info
    if [ "$({REPLICABLEDIRECTORY}: -1)" = "/" ]
    then
        DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}${SHA1}"
    else
        DESTINATIONDIRECTORY="${REPLICABLEDIRECTORY}/${SHA1}"
    fi
    if [ ! read DESTINATIONFROMFILE < "DESTINATION.txt" ]
    then
       echo "Error: unable to read DESTINATION.txt."
       graceful_exit 1
    fi
    if [ "${{DESTINATIONFROMFILE}: -1)" = "/" ]
    then
        if [ "${DESTINATIONDIRECTORY}/" != "${DESTINATIONFROMFILE}"
        then
            echo "Error: destinations from DESTINATION.txt and PATHS.txt do not match."
            graceful_exit 1
        fi
    else
        if [ "${DESTINATIONDIRECTORY}" != "${DESTINATIONFROMFILE}"
        then
            echo "Error: destination from DESTINATION.txt and PATHS.txt do not match."
            graceful_exit 1
        fi
    fi
    cd "${REPLICABLEEXPERIMENTDIRECTORY}"
    REPLICABLEEXPERIMENTSHA1="$(git rev-pase --short HEAD)"
    cd "${CURRENTDIRECTORY}"
    chmod -R +rwx "${DESTINATIONDIRECTORY}"
    echo "$1 ${REPLICABLEEXPERIMENTSHA1}" >> "${DESTINATIONDIRECTORY}/DIARY.txt"
    return 0
}

function gracefully_exit_successful_replicable_experiment_script()
{
   chmod -R +rx "${DESTINATIONDIRECTORY}"
   exit 0
}

function replicable_experiment_cleanup()
{
    export REPLICABLE=1
    CURRENTDIRECTORY=$(pwd)
    if [ ! read REPLICABLEEXPERIMENTDIRECTORY < "REPLICABLE-EXPERIMENT.txt" ]
    then
        echo "Unable to read REPLICABLE-EXPERIMENT.txt."
        graceful_exit 1
    fi
    get_destination_info 1
    if echo "${DEBUGDIRECTORY}" > "DESTINATION.txt"
    then
        export REVERTDESTINATIONINFO=1
    fi
    cd "${REPLICABLEEXPERIMENTDIRECTORY}"
    REPLICABLEEXPERIMENTSHA1="$(git rev-pase --short HEAD)"
    cd "${CURRENTDIRECTORY}"
    chmod -R +rwx "${DESTINATIONDIRECTORY}"
    echo "$1 ${REPLICABLEEXPERIMENTSHA1}" >> "${DESTINATIONDIRECTORY}/DIARY.txt"
    chmod -R +rx "${DESTINATIONDIRECTORY}"
    return 0
}
