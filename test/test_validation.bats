#!/usr/bin/env bats

load '../lib/validation.sh'


@test "Valid database name passes" {
  run is_valid_name "valid_db"
  [ "$status" -eq 0 ]
}
@test "Name starting with number fails" {
  run is_valid_name "1invalid"
  [ "$status" -ne 0 ]
}
@test "Name with special characters fails" {
  run is_valid_name "invalid@name"
  [ "$status" -ne 0 ]
}
@test "Empty name fails" {
  run is_valid_name ""
  [ "$status" -ne 0 ]
}
@test "Name exceeding max length fails" {
  run is_valid_name "$(printf 'a%.0s' {1..31})"
  [ "$status" -ne 0 ]
}

@test "is_directory returns 0 for a directory" {
  mkdir -p tmpdir
  run is_directory "tmpdir"
  [ "$status" -eq 0 ]
  rm -r tmpdir
}

@test "is_directory returns 1 for a file" {
  touch tmpfile
  run is_directory "tmpfile"
  [ "$status" -ne 0 ]
  rm tmpfile
}

@test "is_file returns 0 for a file" {
  touch tmpfile
  run is_file "tmpfile"
  [ "$status" -eq 0 ]
  rm tmpfile
}

@test "is_file returns 1 for a directory" {
  mkdir -p tmpdir
  run is_file "tmpdir"
  [ "$status" -ne 0 ]
  rm -r tmpdir
}

@test "name_exists returns 0 if name exists in directory" {
  mkdir -p tmpdir
  touch tmpdir/existing
  run name_exists "tmpdir" "existing"
  [ "$status" -eq 0 ]
  rm -r tmpdir
}

@test "name_exists returns 1 if name does not exist in directory" {
  mkdir -p tmpdir
  run name_exists "tmpdir" "missing"
  [ "$status" -ne 0 ]
  rm -r tmpdir
}


@test "is_number returns 0 for positive integer" {
  run is_number "123"
  [ "$status" -eq 0 ]
}

@test "is_number returns 0 for negative integer" {
  run is_number "-456"
  [ "$status" -eq 0 ]
}

@test "is_number returns 1 for decimal number" {
  run is_number "12.34"
  [ "$status" -ne 0 ]
}

@test "is_number returns 1 for non-numeric string" {
  run is_number "abc"
  [ "$status" -ne 0 ]
}

@test "is_number returns 1 for empty string" {
  run is_number ""
  [ "$status" -ne 0 ]
}

@test "is_number returns 1 for number with spaces" {
  run is_number " 123 "
  [ "$status" -ne 0 ]
}

@test "is_number returns 1 for number with plus sign" {
  run is_number "+789"
  [ "$status" -ne 0 ]
}

