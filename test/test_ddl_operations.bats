#!/usr/bin/env bats

load '../lib/ddl_operations.sh'


@test "create_database creates a new database directory" {
  run create_database "t_s_e_t_15_54_015_257_db_test"
  [ "$status" -eq 0 ]
  [ -d "./database/t_s_e_t_15_54_015_257_db_test" ] 
  rm -r "./database/t_s_e_t_15_54_015_257_db_test"
}

@test "create_database creates with invalid name" {
  run create_database "test db"
  [ "$status" -ne 0 ]
}

