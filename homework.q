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

    CsvIterator iterator (s, "UTF-8", csv_opts);

    Datasource ds (connection);

    hash mapping_customers = {
        "cust_id" : ("sequence" : "customers_seq"),
        "cust_num" : "CustNmbr",
        "cust_name" : "CustomerName"
    };
    Table customers (ds, "customers", {});
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
    Table customer_inventory (ds, "customer_inventory", {});
    InboundTableMapper customer_inventory_mapper (customer_inventory, mapping_customer_inventory);

    while (iterator.next()) {
        if (!existing_customers {iterator.CustNmbr}) {
            if (verbose)
                printf ("Inserting new customer no. '%d' into `customers`.\n", iterator.CustNmbr);
            hash rv = customers_mapper.insertRow (iterator.getRecord ());
            existing_customers {iterator.CustNmbr} = rv.cust_id;
        }
        customer_inventory_mapper.insertRow (iterator.getRecord ());
    }
    ds.commit ();
}
catch (hash ex) {
    printf ("%s: %s: %s\n", get_ex_pos(ex), ex.err, ex.desc);
}

