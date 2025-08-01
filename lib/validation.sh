VALIDATION_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

bash $VALIDATION_DIR_PATH/log.sh

DELIM=$'\x1F'


is_valid_name() {
    local name="$1"
    local max_length=30

    if [[ -z "$name" ]]; then
        log "ERROR" "Empty database name entered"
        return 1
    fi

    if (( ${#name} > max_length )); then
        log "ERROR" "Database name too long: $name"
        return 1
    fi

    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log "ERROR" "Invalid name: $name - must start with a letter or underscore and contain only alphanumeric characters and underscores"
        return 1
    fi

    log "INFO" "Valid DB name: $name"
    return 0
}

is_directory() {
    local src="$1"
    if [[ -d "$src" ]]; then
        log "INFO" "'$src' is a directory"
        return 0
    else
        log "ERROR" "'$src' is not a directory"
        return 1
    fi
}

is_file() {
    local src="$1"
    if [[ -f "$src" ]]; then
        log "INFO" "'$src' is a file"
        return 0
    else
        log "ERROR" "'$src' is not a file"
        return 1
    fi
}

name_exists() {
    local src="$1"
    local name="$2"
    if [[ -e "$src/$name" ]]; then
        return 0
    else
        log "INFO" "Name '$name' does not exist "
        return 1
    fi
}

is_number() {
    local value="$1"
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        log "INFO" "'$value' is a valid number"
        return 0
    else
        log "ERROR" "'$value' is not a valid number"
        return 1
    fi
}


validate_nullable() {
    local value="$1"
    local is_nullable="$2"
    local column_name="$3"

    if [[ "$is_nullable" == "yes" ]]; then
        return 0
    elif [[ -z "$value" ]]; then
        log "ERROR" "Value for $column_name cannot be empty."
        return 1
    fi
    return 0
}

validate_data_type() {
    local value="$1"
    local data_type="$2"
    local column_name="$3"

    if [[ "$data_type" == "int" ]]; then
        if ! is_number "$value"; then
            log "ERROR" "Invalid value for $column_name: $value. Expected integer."
            return 1
        fi
    fi
    log "INFO" "Value '$value' is valid for $column_name with data type $data_type."
    return 0
}

validate_primary_key() {
    local value="$1"
    local is_primary="$2"
    local data_file="$3"
    local column_index="$4"
    local column_name="$5"

    if [[ "$is_primary" == "yes" ]]; then
        if [[ -s "$data_file" ]]; then
            while IFS=$DELIM read -r -a fields; do
                if [[ "${fields[$column_index]}" == "$value" ]]; then
                    log "ERROR" "Primary key violation: '$value' already exists for $column_name."
                    return 1
                fi
            done < "$data_file"
        fi
    fi
    return 0
}


