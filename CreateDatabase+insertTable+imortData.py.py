import os
import pandas as pd
import mysql.connector
from mysql.connector import Error


# ============================================================
# CONFIGURATION
# ============================================================

# CSV FILE LOCATION
CSV_FOLDER = r"D:\SushilITProjects\SQL_Projects\brazilian-ecommerce\csvdata\raw"

# MYSQL CONNECTION
MYSQL_HOST = "localhost"
MYSQL_PORT = 3307
MYSQL_USER = "root"
MYSQL_PASSWORD = "12345678"
MYSQL_DATABASE = "olist_brazilian_ecommerce"


# ============================================================
# CREATE FRESH DATABASE
# ============================================================

def create_database():

    try:

        print("\nConnecting to MySQL server...")

        connection = mysql.connector.connect(
            host=MYSQL_HOST,
            port=MYSQL_PORT,
            user=MYSQL_USER,
            password=MYSQL_PASSWORD
        )

        cursor = connection.cursor()

        # ----------------------------------------------------
        # DROP OLD DATABASE
        # ----------------------------------------------------

        print(
            f"Dropping old database '{MYSQL_DATABASE}' "
            f"if it exists..."
        )

        cursor.execute(
            f"DROP DATABASE IF EXISTS `{MYSQL_DATABASE}`"
        )

        # ----------------------------------------------------
        # CREATE NEW DATABASE
        # ----------------------------------------------------

        print(
            f"Creating database '{MYSQL_DATABASE}'..."
        )

        cursor.execute(
            f"""
            CREATE DATABASE `{MYSQL_DATABASE}`
            CHARACTER SET utf8mb4
            COLLATE utf8mb4_unicode_ci
            """
        )

        connection.commit()

        cursor.close()
        connection.close()

        print(
            f"Database '{MYSQL_DATABASE}' created successfully."
        )

    except Error as e:

        print("\nERROR creating database:")
        print(e)

        raise


# ============================================================
# CONNECT TO DATABASE
# ============================================================

def get_connection():

    return mysql.connector.connect(

        host=MYSQL_HOST,

        port=MYSQL_PORT,

        user=MYSQL_USER,

        password=MYSQL_PASSWORD,

        database=MYSQL_DATABASE
    )


# ============================================================
# CREATE TABLES
# ============================================================

def create_tables(connection):

    cursor = connection.cursor()

    print("\nCreating tables...")

    # Disable foreign key checking
    cursor.execute(
        "SET FOREIGN_KEY_CHECKS = 0"
    )

    # ========================================================
    # CUSTOMERS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_customers (

            customer_id VARCHAR(50) PRIMARY KEY,

            customer_unique_id VARCHAR(50),

            customer_zip_code_prefix INT,

            customer_city VARCHAR(100),

            customer_state VARCHAR(10),

            INDEX idx_customer_unique_id(
                customer_unique_id
            ),

            INDEX idx_customer_state(
                customer_state
            )

        )
    """)

    print("Created table: olist_customers")

    # ========================================================
    # SELLERS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_sellers (

            seller_id VARCHAR(50) PRIMARY KEY,

            seller_zip_code_prefix INT,

            seller_city VARCHAR(100),

            seller_state VARCHAR(10),

            INDEX idx_seller_state(
                seller_state
            )

        )
    """)

    print("Created table: olist_sellers")

    # ========================================================
    # PRODUCTS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_products (

            product_id VARCHAR(50) PRIMARY KEY,

            product_category_name VARCHAR(100),

            product_name_length INT,

            product_description_length INT,

            product_photos_qty INT,

            product_weight_g INT,

            product_length_cm INT,

            product_height_cm INT,

            product_width_cm INT,

            INDEX idx_product_category(
                product_category_name
            )

        )
    """)

    print("Created table: olist_products")

    # ========================================================
    # ORDERS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_orders (

            order_id VARCHAR(50) PRIMARY KEY,

            customer_id VARCHAR(50),

            order_status VARCHAR(30),

            order_purchase_timestamp DATETIME,

            order_approved_at DATETIME,

            order_delivered_carrier_date DATETIME,

            order_delivered_customer_date DATETIME,

            order_estimated_delivery_date DATETIME,

            INDEX idx_order_customer(
                customer_id
            ),

            INDEX idx_order_status(
                order_status
            ),

            INDEX idx_order_purchase(
                order_purchase_timestamp
            ),

            FOREIGN KEY(customer_id)

                REFERENCES olist_customers(
                    customer_id
                )

        )
    """)

    print("Created table: olist_orders")

    # ========================================================
    # ORDER ITEMS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_order_items (

            order_id VARCHAR(50),

            order_item_id INT,

            product_id VARCHAR(50),

            seller_id VARCHAR(50),

            shipping_limit_date DATETIME,

            price DECIMAL(10,2),

            freight_value DECIMAL(10,2),

            PRIMARY KEY(
                order_id,
                order_item_id
            ),

            INDEX idx_item_product(
                product_id
            ),

            INDEX idx_item_seller(
                seller_id
            ),

            FOREIGN KEY(order_id)

                REFERENCES olist_orders(
                    order_id
                ),

            FOREIGN KEY(product_id)

                REFERENCES olist_products(
                    product_id
                ),

            FOREIGN KEY(seller_id)

                REFERENCES olist_sellers(
                    seller_id
                )

        )
    """)

    print("Created table: olist_order_items")

    # ========================================================
    # PAYMENTS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_order_payments (

            order_id VARCHAR(50),

            payment_sequential INT,

            payment_type VARCHAR(30),

            payment_installments INT,

            payment_value DECIMAL(10,2),

            PRIMARY KEY(
                order_id,
                payment_sequential
            ),

            INDEX idx_payment_type(
                payment_type
            ),

            FOREIGN KEY(order_id)

                REFERENCES olist_orders(
                    order_id
                )

        )
    """)

    print("Created table: olist_order_payments")

    # ========================================================
    # REVIEWS
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_order_reviews (

            review_id VARCHAR(50),

            order_id VARCHAR(50),

            review_score INT,

            review_comment_title TEXT,

            review_comment_message TEXT,

            review_creation_date DATETIME,

            review_answer_timestamp DATETIME,

            PRIMARY KEY(review_id),

            INDEX idx_review_order(
                order_id
            ),

            INDEX idx_review_score(
                review_score
            ),

            FOREIGN KEY(order_id)

                REFERENCES olist_orders(
                    order_id
                )

        )
    """)

    print("Created table: olist_order_reviews")

    # ========================================================
    # GEOLOCATION
    # ========================================================

    cursor.execute("""
        CREATE TABLE olist_geolocation (

            geolocation_zip_code_prefix INT,

            geolocation_lat DECIMAL(10,7),

            geolocation_lng DECIMAL(10,7),

            geolocation_city VARCHAR(100),

            geolocation_state VARCHAR(10),

            INDEX idx_geo_zip(
                geolocation_zip_code_prefix
            ),

            INDEX idx_geo_state(
                geolocation_state
            )

        )
    """)

    print("Created table: olist_geolocation")

    # ========================================================
    # CATEGORY TRANSLATION
    # ========================================================

    cursor.execute("""
        CREATE TABLE product_category_translation (

            product_category_name VARCHAR(100) PRIMARY KEY,

            product_category_name_english VARCHAR(100)

        )
    """)

    print(
        "Created table: product_category_translation"
    )

    # Enable foreign keys
    cursor.execute(
        "SET FOREIGN_KEY_CHECKS = 1"
    )

    connection.commit()

    cursor.close()

    print("\nAll tables created successfully.")


# ============================================================
# CSV → TABLE MAPPING
# ============================================================

CSV_MAPPING = {

    "olist_customers_dataset.csv":
        "olist_customers",

    "olist_sellers_dataset.csv":
        "olist_sellers",

    "olist_products_dataset.csv":
        "olist_products",

    "olist_orders_dataset.csv":
        "olist_orders",

    "olist_order_items_dataset.csv":
        "olist_order_items",

    "olist_order_payments_dataset.csv":
        "olist_order_payments",

    "olist_order_reviews_dataset.csv":
        "olist_order_reviews",

    "olist_geolocation_dataset.csv":
        "olist_geolocation",

    "product_category_name_translation.csv":
        "product_category_translation"
}


# ============================================================
# DATE COLUMNS
# ============================================================

DATE_COLUMNS = {

    "olist_orders": [

        "order_purchase_timestamp",

        "order_approved_at",

        "order_delivered_carrier_date",

        "order_delivered_customer_date",

        "order_estimated_delivery_date"

    ],

    "olist_order_items": [

        "shipping_limit_date"

    ],

    "olist_order_reviews": [

        "review_creation_date",

        "review_answer_timestamp"

    ]
}


# ============================================================
# NUMERIC COLUMNS
# ============================================================

NUMERIC_COLUMNS = {

    "olist_customers": [

        "customer_zip_code_prefix"

    ],

    "olist_sellers": [

        "seller_zip_code_prefix"

    ],

    "olist_products": [

        "product_name_length",

        "product_description_length",

        "product_photos_qty",

        "product_weight_g",

        "product_length_cm",

        "product_height_cm",

        "product_width_cm"

    ],

    "olist_order_items": [

        "order_item_id",

        "price",

        "freight_value"

    ],

    "olist_order_payments": [

        "payment_sequential",

        "payment_installments",

        "payment_value"

    ],

    "olist_order_reviews": [

        "review_score"

    ],

    "olist_geolocation": [

        "geolocation_zip_code_prefix",

        "geolocation_lat",

        "geolocation_lng"

    ]
}


# ============================================================
# PREPARE DATA
# ============================================================

def prepare_dataframe(df, table_name):

    # --------------------------------------------------------
    # Clean column names
    # --------------------------------------------------------

    df.columns = [

        column.strip().replace(
            "\ufeff",
            ""
        )

        for column in df.columns

    ]

    # --------------------------------------------------------
    # Replace empty values
    # --------------------------------------------------------

    df = df.replace(
        {
            "": None,
            "nan": None,
            "NaN": None
        }
    )

    # --------------------------------------------------------
    # Convert DATE columns
    # --------------------------------------------------------

    if table_name in DATE_COLUMNS:

        for column in DATE_COLUMNS[table_name]:

            if column in df.columns:

                df[column] = pd.to_datetime(

                    df[column],

                    errors="coerce"

                )

                df[column] = df[column].where(

                    df[column].notna(),

                    None

                )

    # --------------------------------------------------------
    # Convert NUMERIC columns
    # --------------------------------------------------------

    if table_name in NUMERIC_COLUMNS:

        for column in NUMERIC_COLUMNS[table_name]:

            if column in df.columns:

                df[column] = pd.to_numeric(

                    df[column],

                    errors="coerce"

                )

    # --------------------------------------------------------
    # Convert NaN → None
    # --------------------------------------------------------

    df = df.astype(object).where(

        pd.notna(df),

        None

    )

    return df


# ============================================================
# LOAD CSV INTO MYSQL
# ============================================================

def load_csv(
    connection,
    csv_file,
    table_name
):

    file_path = os.path.join(

        CSV_FOLDER,

        csv_file

    )

    # --------------------------------------------------------
    # Check file
    # --------------------------------------------------------

    if not os.path.exists(file_path):

        print()

        print(
            f"WARNING: File not found:"
        )

        print(file_path)

        return

    print("\n")

    print("=" * 70)

    print(
        f"Loading: {csv_file}"
    )

    print(
        f"Table  : {table_name}"
    )

    print("=" * 70)

    try:

        # ----------------------------------------------------
        # Read CSV
        # ----------------------------------------------------

        df = pd.read_csv(

            file_path,

            encoding="utf-8"

        )

        print(
            f"Rows found: {len(df):,}"
        )

        # ----------------------------------------------------
        # Prepare data
        # ----------------------------------------------------

        df = prepare_dataframe(

            df,

            table_name

        )

        columns = list(
            df.columns
        )

        # ----------------------------------------------------
        # SQL column names
        # ----------------------------------------------------

        column_names = ", ".join(

            f"`{column}`"

            for column in columns

        )

        # ----------------------------------------------------
        # SQL placeholders
        # ----------------------------------------------------

        placeholders = ", ".join(

            ["%s"] * len(columns)

        )

        # ----------------------------------------------------
        # INSERT SQL
        # ----------------------------------------------------

        sql = f"""

            INSERT IGNORE INTO `{table_name}`

            ({column_names})

            VALUES ({placeholders})

        """

        cursor = connection.cursor()

        # ----------------------------------------------------
        # Batch size
        # ----------------------------------------------------

        batch_size = 5000

        total_rows = len(df)

        inserted = 0

        # ----------------------------------------------------
        # Insert data in batches
        # ----------------------------------------------------

        for start in range(

            0,

            total_rows,

            batch_size

        ):

            end = min(

                start + batch_size,

                total_rows

            )

            batch = df.iloc[
                start:end
            ]

            data = [

                tuple(row)

                for row in batch.itertuples(

                    index=False,

                    name=None

                )

            ]

            cursor.executemany(

                sql,

                data

            )

            connection.commit()

            inserted += len(data)

            print(

                f"Inserted "
                f"{inserted:,}/"
                f"{total_rows:,}",

                end="\r"

            )

        cursor.close()

        print()

        print(

            f"SUCCESS: "
            f"{inserted:,} rows "
            f"loaded into "
            f"{table_name}"

        )

    except Exception as e:

        print()

        print(
            f"ERROR loading {csv_file}:"
        )

        print(e)


# ============================================================
# VERIFY TABLES
# ============================================================

def verify_tables(connection):

    cursor = connection.cursor()

    print("\n")

    print("=" * 70)

    print("FINAL TABLE ROW COUNTS")

    print("=" * 70)

    for table_name in CSV_MAPPING.values():

        cursor.execute(

            f"""
            SELECT COUNT(*)
            FROM `{table_name}`
            """

        )

        count = cursor.fetchone()[0]

        print(

            f"{table_name:<35}"
            f"{count:>12,} rows"

        )

    cursor.close()


# ============================================================
# MAIN PROGRAM
# ============================================================

def main():

    print("\n")

    print("=" * 70)

    print(
        "BRAZILIAN E-COMMERCE "
        "MYSQL DATABASE IMPORTER"
    )

    print("=" * 70)

    # ========================================================
    # STEP 1: CHECK CSV FOLDER
    # ========================================================

    print("\nSTEP 1: Checking CSV folder...")

    if not os.path.exists(CSV_FOLDER):

        print(
            "\nERROR: CSV folder does not exist:"
        )

        print(CSV_FOLDER)

        return

    print("CSV folder found.")

    # ========================================================
    # STEP 2: CREATE FRESH DATABASE
    # ========================================================

    print("\nSTEP 2: Creating fresh database...")

    try:

        create_database()

    except Exception:

        print(
            "\nDatabase creation failed."
        )

        return

    # ========================================================
    # STEP 3: CONNECT TO DATABASE
    # ========================================================

    print("\nSTEP 3: Connecting to database...")

    try:

        connection = get_connection()

        print(
            f"Connected to '{MYSQL_DATABASE}'"
        )

    except Error as e:

        print(
            "\nMySQL connection failed:"
        )

        print(e)

        return

    try:

        # ====================================================
        # STEP 4: CREATE TABLES
        # ====================================================

        print(
            "\nSTEP 4: Creating tables..."
        )

        create_tables(
            connection
        )

        # ====================================================
        # STEP 5: IMPORT CSV FILES
        # ====================================================

        print(
            "\nSTEP 5: Importing CSV files..."
        )

        for csv_file, table_name in CSV_MAPPING.items():

            load_csv(

                connection,

                csv_file,

                table_name

            )

        # ====================================================
        # STEP 6: VERIFY DATA
        # ====================================================

        print(
            "\nSTEP 6: Verifying database..."
        )

        verify_tables(
            connection
        )

    finally:

        connection.close()

    # ========================================================
    # FINISHED
    # ========================================================

    print("\n")

    print("=" * 70)

    print(
        "DATABASE IMPORT COMPLETED"
    )

    print("=" * 70)

    print()

    print(
        "Database:"
    )

    print(
        MYSQL_DATABASE
    )

    print()

    print(
        "You can now open MySQL Workbench "
        "and run SQL queries."
    )

    print()


# ============================================================
# RUN PROGRAM
# ============================================================

if __name__ == "__main__":

    main()