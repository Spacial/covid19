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
    OLDIFS=${IFS}
    IFS=''
    while read c; 
    do 
        NEW=$(camelcase ${c})
        DEBUG echo "creating ${c} file: ${TMPDIR}/raw_${NEW}.data"
        grep ${c} ${OLDDIR}/${INPUTFILE} > ${TMPDIR}/raw_${NEW}.data
    done < ${TMPDIR}/${TMPFILE}
    TOTFILES=$(ls -l ${TMPDIR}/raw_*.data | wc -l)
    DEBUG echo "There were ${TOTFILES} created"
    IFS=${OLDIFS}
}

function zerocountry(){
    FILE=${1}
    TOTAL=$(wc -l ${FILE} | cut -d' ' -f1)
    for linenumber in $(seq 1 ${TOTAL}); do
        line=$(sed -n ${linenumber}p ${FILE})
        data=$(echo ${line} | cut -d',' -f2-)
        echo "${linenumber},${data}" >> ${FILE}.adjusted
    done
}

function adjustdayzero(){
    for data in $(ls ${TMPDIR}/raw_*.data); do
        DEBUG echo "Adjusting to relative zero day country file: ${data}"
        zerocountry ${data}
    done 
}

function datatopandas(){

    ### ARRUMAR


    FILE=${1}
    OUTFILE=${2}
    CURCOL=${3}
    DEBUG echo "DATATOPANDAS RECEIVED: ${FILE}, ${OUTFILE}, ${CURCOL}"
    #date,location,new_cases,new_deaths,total_cases,total_deaths
    # TODO: should validate colunm 2 to garantee that is the same country, ever. (with sort & uniq)
    CONSTOTAL=$(wc -l ${OUTFILE} | cut -d' ' -f1)
    TOTAL=$(wc -l ${FILE} | cut -d' ' -f1)
    COUNTRY=$(head -n 1 ${FILE} | cut -d',' -f2)
    HEADER=$(head -n 1 ${OUTFILE})
    RANDLOCAL=$(LANG=C tr -dc A-Za-z0-9 < /dev/urandom  | fold -w ${1:-32} | head -n 1)
    TMPLOCAL=${TMPDIR}/${RANDLOCAL}
    echo "${HEADER},${COUNTRY}" > ${TMPLOCAL}
    for nline in $(seq 2 ${CONSTOTAL}); do
        CONSDATA=$(sed -n ${nline}p ${OUTFILE})
        if [ ${nline} -le ${TOTAL} ]; then 
            FILEDATA=$(sed -n ${nline}p ${FILE})
            THISCASE=$(echo ${FILEDATA} | cut -d',' -f${CURCOL})
            echo "${CONSDATA},${THISCASE}" >> ${TMPLOCAL}
        else 
            echo "${CONSDATA},-" >> ${TMPLOCAL}
        fi
    done 
    DEBUG echo "moving: ${TMPLOCAL} to ${OUTFILE}"
    mv ${TMPLOCAL} ${OUTFILE}
}

function datatoallpandas(){


    ##### ARRUMAR




    PANDAFILE=${1}
    CONSFILE=${2}
    DEBUG echo "DATATOALLPANDAS RECEIVED: ${PANDAFILE}, ${CONSFILE}"
    declare -a samecases=("new_cases" 
                      "new_deaths" 
                      "total_cases" 
                      "total_deaths")
    DEBUG echo "DATAPANDAS Cases to create: ${samecases}"
    COL=3
    for i in "${samecases[@]}"; do
        THEFILE=$(echo "${CONSFILE}_${i}")
        DEBUG echo "adding to: ${THEFILE}"
        datatopandas ${THEFILE} ${PANDAFILE} ${COL}
        COL=$(echo ${COL}+1 | bc)
    done
}

function fill(){
    FFILE=${1}
    MAXDAY=${2}
    DEBUG echo "filling the file: ${FFILE} with ${MAXDAY} days...."
    echo "day," > ${FFILE}
    for i in $(seq 0 ${MAXDAY}); do
        echo "${i}," >> ${FFILE}
    done
}

function populateall(){
    CFILE=${1}
    MAXDAY=${2}
    declare -a cases=("new_cases" 
                      "new_deaths" 
                      "total_cases" 
                      "total_deaths")
    DEBUG echo "Cases to create: ${cases}"
    for i in "${cases[@]}"; do
        THEFILE=$(echo "${CFILE}_${i}")
        DEBUG echo "Creating file: ${THEFILE}"
        fill ${THEFILE} ${MAXDAY}
    done
}

function consolidate(){
    TMPNOW=$(date '+%Y%m%dT%H%M%S')
    RANDATA=$(LANG=C tr -dc A-Za-z0-9 < /dev/urandom  | fold -w ${1:-16} | head -n 1)
    CONSOLIDATEDFILE=$(echo ${TMPDIR}/a${TMPNOW}${RANDATA})
    TOTALFILES=$(ls ${TMPDIR}/raw_*.adjusted | wc -l)
    MAXDAY=$(wc -l ${TMPDIR}/raw_World*.adjusted | cut -d' ' -f1)
    CURCOL=1
    populateall ${CONSOLIDATEDFILE} ${MAXDAY}
    for countrydataf in $(ls ${TMPDIR}/raw_*.adjusted); do
        DEBUG echo "Consolidating to relative zero day country file: ${countrydataf}"
        DEBUG echo "sending data: ${CONSOLIDATEDFILE} ignore: ${CURCOL} ${TOTALFILES} ${MAXDAY}"
        #datatoallpandas ${countrydataf} ${CONSOLIDATEDFILE} ${CURCOL} ${TOTALFILES} ${MAXDAY}
        datatoallpandas ${countrydataf} ${CONSOLIDATEDFILE}
        #CURCOL=$(echo "${CURCOL}+1" | bc)
    done 
    DEBUG echo "casos (colunas): ${cases} "
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

<<<<<<< HEAD
DEBUG echo "inputfile seted to: ${INPUTFILE}"
DEBUG echo "tmpdir: /tmp/${TMPNOW}"
DEBUG echo "tmpfile: ${TMPFILE}"
=======

DEBUG echo "inputfile seted to: ${INPUTFILE}" 
DEBUG echo "tmpdir: /tmp/${TMPNOW}" 
DEBUG echo "tmpfile: ${TMPFILE}" 
>>>>>>> ff09c6e7c859a0f2c0dc2e3ad70e705dd040c8c5

if [ "${COUNTRIESFILE}" == "" ]; then
    getcountries
else
    COUNTRIESCP=$(echo "${TMPDIR}/${TMPFILE}")
    cp ${COUNTRIESFILE} ${COUNTRIESCP}
fi

DEBUG echo "2x - countriesfile seted to: ${COUNTRIESFILE}"

<<<<<<< HEAD
forkcountries

adjustdayzero

consolidate
=======
# forkcountries
string_separator_camelcase "-" "This is a string"  
string_camelcase_separator "d" "This Is A String" # This_Is_A_String 
 
>>>>>>> ff09c6e7c859a0f2c0dc2e3ad70e705dd040c8c5

restorenv
