#!/bin/bash 
#    prepare WHO data to plot by 0 day 
# Author: spacial (email: see [1] 
# [1] $ echo "spacialATg-m-a-i-lDOTc-o-m" | sed -e 's/AT/@/g'  | sed -e 's/DOT/\./g' | sed -e 's/-//g'
# Date: 18/03/2020 
# License: GPL v3 or superior 
##### 
# Deps :
##### 
# Params: 
#     see usage()  
##### 
# Changelog: 
# 20200318Z - initial version (0.1) 
##### 
# Wish /TODO:
##### 
# Functions 
function usage() { 
        echo "Use: $0 inputfile.csv [countries.txt]" 
        echo 'Parameters: inputfile.csv [countries.txt]    
               - inputfile.csv ($1) - file from covid19 cases from WHO (csv format).
               - [countries.txt] ($2) - file with selected countries (to narrow graphics), one per line.

               output: data prepared to pandas/jupyter on screen
        '
        echo  " * Tip: to debug script, add _DEBUG=on before running."       
        return 0 
        exit 
} 
 
DEBUG(){ 
        [ "$_DEBUG" == "on" ] && $@ || : 
} 
 
function saveenv(){ 
    OLDDIR=$(pwd) 
    OLDLC_TYPE=${LC_TYPE} 
} 

function setenv(){ 
    LC_CTYPE=C 
    TIME=$(date +"%H") 
    FULLTIME=$(date '+%Y/%m/%d %H:%M:%S') 
    createtmp 
    TMPDIR=$(echo ".tmp-${TMPNOW}") 
    DEBUG echo "mkdir -p ${TMPDIR}" 
    LOGFILE=${TMPDIR}/prepdata.log 
    mkdir -p ${TMPDIR} 
} 

function restorenv(){ 
    cd ${OLDDIR} 
    LC_TYPE=${OLDLC_TYPE} 
    DEBUG echo "rm -rf ${TMPDIR}" 
    # rm -rf ${TMPDIR} # uncomment to adjust
}

function createtmp(){ 
    TMPNOW=$(date '+%Y%m%dT%H%M%S')
    RANDATA=$(LANG=C tr -dc A-Za-z0-9 < /dev/urandom  | fold -w ${1:-16} | head -n 1) 
    TMPFILE=$(echo ${TMPNOW}${RANDATA})
    DEBUG echo "${TMPNOW} // ${RANDATA}" 
    return  
} 

function string_escape() {
    local type
    local chars
    local string

    if [[ "${1}" = "--type" ]] || [[ "${1}" = "-t" ]]; then
        type="${2}"
        shift 2
    else
        type="quote"
    fi

    case "${type}" in 
        quote) 
            chars=="'\"" 
        ;; 
        regex) 
            chars=']$.*+\^?()[' 
        ;;
        *)
            return 1
        ;;
    esac

    if [[ -z "${1}" ]] && [ ! -t 0 ]; then 
        string=$(cat <&0) 
    else 
        string="${1}" 
    fi

    echo "${string}" | sed -E "s/([${chars}])/\\\\\1/g" 
}


function string_separator_camelcase(){
    local separator="${1}"
    local string="${2}"

    if [[ -z "${separator}" ]]; then
        return 1
    fi

    if [[ -z "${string}" ]] && [ ! -t 0 ]; then
        string=$(cat <&0)
    fi

    separator=$(string_escape --type regex "${1}" | sed 's#/#\\/#g')

    echo "${string}" | sed -E "s/${separator}(\w)/\u\1/g"
}

function string_camelcase_underscore() {
    local string="${1}"

    if [[ -z "${string}" ]] && [ ! -t 0 ]; then
        string=$(cat <&0)
    fi

    string_camelcase_separator "_" "${string}"
}

function string_camelcase_separator() {
    local separator="${1}"
    local string="${2}"
    local pattern

    if [[ -z "${separator}" ]]; then
        return 1
    fi

    if [[ -z "${string}" ]] && [ ! -t 0 ]; then
        string=$(cat <&0)
    fi

    separator=$(string_escape --type regex "${1}" | sed 's#/#\\/#g')
    pattern="s/([A-Za-z0-9])([A-Z])/\1${separator}\2/g"

    echo "${string}" | sed -E "${pattern}" | sed -E "${pattern}"
}


function getcountries(){
    DEBUG echo "getting countries from: ${OLDDIR}/${INPUTFILE}"
    DEBUG echo "putting in: ${TMPDIR}/${TMPFILE}"
    cat ${OLDDIR}/${INPUTFILE} | cut -d',' -f2 | grep -v -e '^[[:space:]]*$' | grep -v 'location' | sort | uniq > ${TMPDIR}/${TMPFILE}
    # testar código de retorno
    COUNTRIESFILE=$(echo "${TMPDIR}/${TMPFILE}")
}

function forkcountries(){
    TOTAL=$(cat ${TMPDIR}/${TMPFILE} | wc -l)
    DEBUG echo "Total countries in ${TMPDIR}/${TMPFILE} is ${TOTAL}, forking files.."
    # for c in $(cat ${TMPDIR}/${TMPFILE});
    IFS=''
    while read c; 
    do 
        NEW=$(string_camelcase_underscore ${c})
        DEBUG echo "creating ${c} file: ${TMPDIR}/raw_${NEW}_data.csv"
        grep ${c} ${OLDDIR}/${INPUTFILE} > ${TMPDIR}/raw_${NEW}_data.csv
    done < ${TMPDIR}/${TMPFILE}
    TOTFILES=$(ls -l ${TMPDIR}/raw_*.csv | wc -l)
    DEBUG echo "There were ${TOTFILES} created"
}

#Variáveis
saveenv
setenv

#testing me
if (( EUID == 0 )); then
   echo "Running as root??? no way! bye." 1>&2
   exit 100
fi

## Validating ags
if [ "$#" -eq 2 ]; then
        INPUTFILE=${1} 
        COUNTRIESFILE=${2} 
        DEBUG echo "countriesfile seted to: ${COUNTRIESFILE}" 
fi

if [ ! "$#" -ge 1 ]; then
        usage
        exit 1
else
        INPUTFILE=${1}
        DEBUG echo "no countriesfile seted" 
fi


DEBUG echo "inputfile seted to: ${INPUTFILE}" 
DEBUG echo "tmpdir: /tmp/${TMPNOW}" 
DEBUG echo "tmpfile: ${TMPFILE}" 

if [ "${COUNTRIESFILE}" == "" ]; then
    getcountries
fi

DEBUG echo "2x - countriesfile seted to: ${COUNTRIESFILE}"

# forkcountries
string_separator_camelcase "-" "This is a string"  
string_camelcase_separator "d" "This Is A String" # This_Is_A_String 
 

restorenv
