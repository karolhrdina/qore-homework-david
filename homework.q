#!/usr/bin/env qore

%new-style
%strict-args
%require-types
%enable-all-warnings
%require-types

%requires CsvUtil
%requires TableMapper
%requires SqlUtil
%requires Util

my hash parsed_opts;
my bool verbose = False;
my string input_file;
my string connection;

const Opts =
    (
      "connection"  :   "c,connection=s",
      "input"       :   "i,input=s",
      "verbose"     :   "v,verbose",
      "help"        :   "h,help",
    );


/*! \brief Prints usage information */
nothing sub
usage ()
{
    printf ("Usage:\n");
    printf ("  %s [options]\n", get_script_name ());
    printf ("
Description:
  Parses input CSV file and inserts parsed data into 2 tables in DB.

Options:
  -h / --help              this information
  -v / --verbose           verbose output
  -c / --connection        connection string, i.e. <feature>:<user>@<db_name>
  -i / --input             input file csv file

");
}


/*! \brief Processes command line arguments */
nothing sub
process_cmdline ()
{
    if (!elements ARGV) {
        printf ("Options --connection and --input are mandatory!\n");
        usage ();
        exit (1);
    }

    GetOpt g(Opts);
    parsed_opts = g.parse3(\ARGV);
    
    if (parsed_opts.help) {
        usage ();
        exit (0);
    }
    if (parsed_opts.verbose) {
        verbose = True;
    }
    input_file = parsed_opts.input;
    connection = parsed_opts.connection;
}

#   Script starts here

process_cmdline ();
if (verbose) {
    printf ("Input file == '%s'\n", input_file);
    printf ("DB connection uri == '%s'\n", connection);
}

try {
    FileInputStream s (input_file);
    
    hash csv_opts = {
        "date_format" : "DD/MM/YYYY",
        "encoding" : "UTF-8",
        "header_names" : True,
        "header_lines" : 1,
    };
/*
    hash csv_format = {
        "headers" : (
            "imei", "part_no", "customer_no", "delivery_date", "shipper_customer_no", "order_reference", "customer_name", "description"
        ),
        "fields" : {
            "imei"                  :   "number",
            "part_no"               :   "number",
            "customer_no"           :   "number",
            "delivery_date"         :   {"type" : "date", "format": "DD/MM/YYYY"},
            "shipper_customer_no"   :   "number",
            "order_reference"       :   "string",
            "customer_name"         :   "string",
            "description"           :   "string"
        }
    };
#   Documentation says this should work `CsvIterator iterator (s, "UTF-8", csv_format, csv_opts);`
#   i.e. 	constructor (Qore::InputStream input, string encoding="UTF-8", hash spec, hash opts),
#   but it doesn't
*/
    CsvIterator iterator (s, "UTF-8", csv_opts);

    hash mapping_customers = {
        "cust_id" : ("sequence" : "customers_seq"),
        "cust_num" : "CustNmbr",
        "cust_name" : "CustomerName"
    };
    Table customers (connection, "customers", {});
    InboundTableMapper customers_mapper (customers, mapping_customers);

    
    hash existing_customers = {};   #   `CustNmbr` -> inserted `cust_id`
    hash mapping_customer_inventory = {
        "inventory_id" : ("sequence" : "customer_inventory_seq"),
        "cust_id" : int sub (any x, hash rec) { return existing_customers {rec."CustNmbr"}; },
        "filename" : {"constant" : input_file},
        "part_code" : "PartNmbr",
        "description" : "Description",
        "delivery_date" : "Deldate",
        "order_reference" : "Orderref"
    };
    Table customer_inventory (connection, "customer_inventory", {});
    InboundTableMapper customer_inventory_mapper (customer_inventory, mapping_customer_inventory);

    hash records_to_insert; #   `CustNmbr` -> list of getRecord ()'s to be inserted
                            #   into customer_inventory at a later time due to FK constraint

    while (iterator.next()) {
        if (!existing_customers {iterator.CustNmbr}) {
            if (verbose)
                printf ("Inserting new customer no. '%d' into `customers`.\n", iterator.CustNmbr);
            hash rv = customers_mapper.insertRow (iterator.getRecord ());
            existing_customers {iterator.CustNmbr} = rv.cust_id;
            records_to_insert {iterator.CustNmbr} = list ();
        }
        push records_to_insert {iterator.CustNmbr}, iterator.getRecord ();
    }
    if (verbose)
        printf ("Performing commit on `customers` to save changes.\n");
    customers.commit ();

    foreach string key in (keys records_to_insert) {
        for (int i = 0; i < elements records_to_insert {key}; i++) {
            if (verbose)
                printf ("Inserting new inventory item for customer no. '%d' into `customer_inventory`.\n", key);
            customer_inventory_mapper.insertRow (records_to_insert {key}[i]);
        }
    }
    if (verbose)
        printf ("Performing commit on `customer_inventory` to save changes.\n");
    customer_inventory.commit ();
}
catch (hash ex) {
    printf ("%s: %s: %s\n", get_ex_pos(ex), ex.err, ex.desc);
}

