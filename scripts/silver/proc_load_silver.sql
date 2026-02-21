DELIMITER $$

CREATE PROCEDURE load_silver()
BEGIN
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE batch_start_time DATETIME;
    DECLARE batch_end_time DATETIME;

    -- Error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERROR OCCURRED DURING SILVER LOAD' AS error_msg;
    END;

    SET batch_start_time = NOW();

    /* ================= CRM CUSTOMER ================= */
    SET start_time = NOW();
    TRUNCATE TABLE silver_crm_cust_info;

    INSERT INTO silver_crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname),
        TRIM(cst_lastname),
        CASE
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a'
        END,
        CASE
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            ELSE 'n/a'
        END,
        cst_create_date
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) rn
        FROM bronze_crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE rn = 1;

    SET end_time = NOW();
    SELECT 'crm_cust_info loaded' AS step,
           TIMESTAMPDIFF(SECOND, start_time, end_time) AS seconds;

    /* ================= CRM PRODUCT ================= */
    SET start_time = NOW();
    TRUNCATE TABLE silver_crm_prd_info;

    INSERT INTO silver_crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm,
        prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'),
        SUBSTRING(prd_key, 7),
        TRIM(prd_nm),
        IFNULL(prd_cost, 0),
        CASE
            WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
            WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
            WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
            WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
            ELSE 'n/a'
        END,
        DATE(prd_start_dt),
        DATE_SUB(
            LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt),
            INTERVAL 1 DAY
        )
    FROM bronze_crm_prd_info;

    /* ================= CRM SALES ================= */
    SET start_time = NOW();
    TRUNCATE TABLE silver_crm_sales_details;

    INSERT INTO silver_crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price, dwh_create_date
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE WHEN sls_order_dt = 0 OR CHAR_LENGTH(sls_order_dt) <> 8
             THEN NULL ELSE STR_TO_DATE(sls_order_dt, '%Y%m%d') END,
        CASE WHEN sls_ship_dt = 0 OR CHAR_LENGTH(sls_ship_dt) <> 8
             THEN NULL ELSE STR_TO_DATE(sls_ship_dt, '%Y%m%d') END,
        CASE WHEN sls_due_dt = 0 OR CHAR_LENGTH(sls_due_dt) <> 8
             THEN NULL ELSE STR_TO_DATE(sls_due_dt, '%Y%m%d') END,
        CASE
            WHEN sls_sales IS NULL OR sls_sales <= 0
              OR sls_sales <> sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END,
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END,
        CURDATE()
    FROM bronze_crm_sales_details
    WHERE sls_cust_id REGEXP '^[0-9]+$';

    /* ================= ERP TABLES ================= */
    TRUNCATE TABLE silver_erp_cust_az12;
    INSERT INTO silver_erp_cust_az12
    SELECT
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4) ELSE cid END,
        CASE WHEN bdate > CURDATE() THEN NULL ELSE bdate END,
        CASE
            WHEN UPPER(gen) IN ('F','FEMALE') THEN 'Female'
            WHEN UPPER(gen) IN ('M','MALE') THEN 'Male'
            ELSE 'n/a'
        END,
        CURDATE()
    FROM bronze_erp_cust_az12;

    TRUNCATE TABLE silver_erp_loc_a101;
    INSERT INTO silver_erp_loc_a101
    SELECT
        REPLACE(cid, '-', ''),
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
            WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'n/a'
            ELSE TRIM(cntry)
        END,
        CURDATE()
    FROM bronze_erp_loc_a101;

    TRUNCATE TABLE silver_erp_px_cat_g1v2;
    INSERT INTO silver_erp_px_cat_g1v2
    SELECT id, cat, subcat, maintenance, CURDATE()
    FROM bronze_erp_px_cat_g1v2;

    SET batch_end_time = NOW();
    SELECT 'SILVER LOAD COMPLETED' AS status,
           TIMESTAMPDIFF(SECOND, batch_start_time, batch_end_time) AS total_seconds;
END$$

DELIMITER ;
CALL load_silver();
