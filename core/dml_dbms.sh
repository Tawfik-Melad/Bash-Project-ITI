
#!/bin/bash
DML_DBMS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DML_DBMS_DIR_PATH/../lib/validation.sh"
source "$DML_DBMS_DIR_PATH/../lib/log.sh"
source "$DML_DBMS_DIR_PATH/../lib/dml_operations.sh"

db_name="$1"


PS3="You using -> $db_name database, please enter your choice: "

function dml_main(){
    options=("Create Table" "Drop Table" "List Tables" "Select Table")
    select option in "${options[@]}"
    do
    case $option in
        "Create Table")
            read -p "Enter the table name to create: " table_name
            create_table "$db_name" "$table_name"
            ;;
        "Drop Table")
            read -p "Enter the table name to drop: " table_name
            drop_table "$db_name" "$table_name"

            ;;
        "List Tables")
            list_tables "$db_name"
            ;;
        "Select Table")
            read -p "Enter the table name to select: " table_name
            if name_exists "$DML_DBMS_DIR_PATH/../database/$db_name" "$table_name"; then
                dml_table "$table_name"
            else
                log "ERROR" "Table '$table_name' does not exist in database '$db_name'."
                echo "Table '$table_name' does not exist in database '$db_name'."
            fi
            ;;
        *)
            break
            ;;
    esac
    done
}

function dml_table(){
    local table_name="$1"
    PS3="You using -> $db_name database, and $table_name table, please enter your choice: "
    options=("Table Info" "Insert" "Filter Mod" "Back")
    select option in "${options[@]}"
    do
        case $option in
            "Table Info")
                table_info "$db_name" "$table_name"
                ;;
            "Insert")
                insert_row "$db_name" "$table_name"
                ;;
            "Filter Mod")
                log "INFO" "Filtering data in table '$table_name'."
                bash "$DML_DBMS_DIR_PATH/dql_dbms.sh" "$db_name" "$table_name"
                ;;
            "Back")
                return 0
                ;;
            *)
                break
                ;;
        esac
    done
}




dml_main