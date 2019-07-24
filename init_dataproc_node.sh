#!/bin/bash

readonly jar_modules=$(/usr/share/google/get_metadata_value attributes/jar-modules)
readonly python_modules=$(/usr/share/google/get_metadata_value attributes/python-modules)
readonly spacy_modules=$(/usr/share/google/get_metadata_value attributes/spacy-modules)

if [[ -n ${jar_modules} ]]; then
    readonly auxlib="/usr/lib/hive/auxlib"
    mkdir ${auxlib}

    gsutil cp ${jar_modules} ${auxlib}

    readonly tmpfile=$(mktemp)
    mv "/usr/lib/hive/conf/hive-env.sh" "/usr/lib/hive/conf/hive-env.sh.old"
    sed "s+# export HIVE_AUX_JARS_PATH=+export HIVE_AUX_JARS_PATH=${auxlib}+g" "/usr/lib/hive/conf/hive-env.sh.old" > ${tmpfile}
    mv ${tmpfile} "/usr/lib/hive/conf/hive-env.sh"

    if [[ $(/usr/share/google/get_metadata_value name | tail -c 3) = '-m' ]]; then
        service hive-server2 restart
    fi

fi

if [[ -n ${python_modules} ]]; then
    $(which conda) install ${python_modules}
fi

if [[ -n ${spacy_modules} ]]; then
    python -m spacy download ${spacy_modules}
fi