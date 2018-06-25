# qore-homework-david
Implementation of Qore technologies homework

## How to run

Simplest way is to use the wrapper script:
`./run <input_csv> <db_name>`
i.e.
`./run ./example-products.csv qore_test`

## Assignment

Write script in Qore language to parse input csv file and transform parsed data
into two pre-existing database tables.

## Implementation

The implementation itself is in `homework.q` which has the following usage:

```
Usage:
  homework.q [options]

Description:
  Parses input CSV file and inserts parsed data into 2 tables in DB.

Options:
  -h / --help              this information
  -v / --verbose           verbose output
  -c / --connection        connection string, i.e. <feature>:<user>@<db_name>
  -i / --input             input file csv file
```
