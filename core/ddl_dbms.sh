
#!/bin/bash
DDL_DBMS_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo $DDL_DBMS_DIR_PATH


source "$DDL_DBMS_DIR_PATH/../lib/validation.sh"
source "$DDL_DBMS_DIR_PATH/../lib/log.sh"
source "$DDL_DBMS_DIR_PATH/../lib/ddl_operations.sh"

echo $DDL_DBMS_DIR_PATH

function ddl_main(){
    PS3="Please enter your choice: "
    options=("Create Database" "Drop Database" "List Databases" "Connect to Database" )
    select option in "${options[@]}"
    do
    case $option in
        "Create Database")
            read -p "Enter the database name to create: " db_name
            create_database "$db_name"
            ;;
        "Drop Database")
            read -p "Enter the database name to drop: " db_name
            delete_database "$db_name"
            ;;
        "List Databases")
            echo "all databases : "
            if [ -d "$DDL_DBMS_DIR_PATH/../database" ]; then
                ls -1 "$DDL_DBMS_DIR_PATH/../database"
            else
                echo "No databases found."
            fi
            ;;
        "Connect to Database")
            read -p "Enter the database name to connect: " db_name
            if ! connect_to_database "$db_name"; then
                echo "Failed to connect to database '$db_name'."
                continue
            fi
            echo "Connected to database '$db_name'."
            echo "You can now perform DML operations on this database."
            bash "$DDL_DBMS_DIR_PATH/dml_dbms.sh" "$db_name"
            ;;
        *)
            break
            ;;
    esac
    done
}

ddl_main