
DROP SEQUENCE IF EXISTS customer_inventory_seq;
DROP TABLE IF EXISTS customer_inventory;
DROP SEQUENCE IF EXISTS customers_seq;
DROP TABLE IF EXISTS customers;


--  
--  Customers
--

CREATE TABLE customers (
    cust_id         INT     NOT NULL,
    cust_num        INT     NOT NULL,
    cust_name       VARCHAR (100)   NOT NULL,
    PRIMARY KEY(cust_id)
);
CREATE SEQUENCE customers_seq OWNED BY customers.cust_id;


--
--  Customer Inventory
--


CREATE TABLE customer_inventory (
    inventory_id        INT     NOT NULL,
    cust_id             INT REFERENCES customers (cust_id)    NOT NULL,
    filename            VARCHAR (100)   NOT NULL,
    part_code           INT,
    description         VARCHAR (200),
    delivery_date       TIMESTAMP,
    order_reference     VARCHAR (50),
    PRIMARY KEY(inventory_id)
);
CREATE SEQUENCE customer_inventory_seq OWNED BY customer_inventory.inventory_id;

