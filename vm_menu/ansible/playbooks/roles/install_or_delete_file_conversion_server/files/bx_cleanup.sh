#!/usr/bin/bash
#
# clear temporary trash files for transformer module
#set -x
#
export LANG=en_US.UTF-8
export TERM=linux
PROGNAME=$(basename $0)
PROGPATH=$(dirname $0)

SAVE_LIMIT=7    # save backup for 7 days

LOGS_DIR=/var/log/transformer/
TEMP_DIR=/tmp/transformer/
LOGS_FILE=$LOGS_DIR/transformer_cleanetransformer_cleaner.log
[[ -z $DEBUG ]] && DEBUG=0

# create additional directories
for _dir in $LOGS_DIR $TEMP_DIR; do
    [[ ! -d $_dir ]] && mkdir -p -m 700 $_dir
done

# test options
SITE_DIR=${1}
TR_DIR=${2:-transformercontroller}

if [[ -z "$SITE_DIR" ]]; then
    echo "Usage: $PROGNAME site_dir"
    echo "Ex."
    echo "$PROGNAME /var/www/html/bx_site"
    echo
    exit 1
fi

# logging infor to file
log_to_file() {
    _mess=$1

    echo "$(date +"%Y/%m/%d %H:%M:%S") $$ $_mess" | tee -a $LOGS_FILE
}

error() {
    _mess="${1}"
    _exit="${2:-1}"

    [[ -f $BACK_DB_MYCNF ]] && rm -f $BACK_DB_MYCNF

    log_to_file "$_mess"
    exit $_exit
}

UPLOAD_DIR=$SITE_DIR/upload/
if [[ -z $UPLOAD_DIR ]]; then
    error "There are no upload_dir option for site $SITE_DIR. Exit"
fi

if [[ $TR_DIR =~ "." || $TR_DIR =~ "/" ]]; then
    error "Directory name $TR_DIR contains invalid characters. Exit"
fi

TR_FF="${UPLOAD_DIR}/${TR_DIR}"
if [[ ! -d $TR_FF ]]; then
    error "There are no $TR_FF"
fi

pushd $TR_FF || exit 
find .  -type f -mmin +60 -exec rm -rf "{}" ";" >> $LOGS_FILE 2>&1
popd 
