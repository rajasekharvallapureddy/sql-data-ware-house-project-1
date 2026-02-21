/*
===============================================================================
Quality Checks – Silver Layer (MySQL)
===============================================================================
Purpose:
    Validate data quality, consistency, and standardization in Silver tables.

Run After:
    Silver layer load is completed.
===============================================================================
*/

USE silver;

-- =====================================================
-- Checking silver_crm_cust_info
-- =====================================================

-- Check for NULLs or duplicate primary keys
-- Expectation: No rows returned
SELECT
    cst_id,
    COUNT(*) AS cnt
FROM silver_crm_cust_info
GROUP BY cst_id
HAVING cnt > 1 OR cst_id IS NULL;

-- Check for unwanted spaces
-- Expectation: No rows returned
SELECT
    cst_key
FROM silver_crm_cust_info
WHERE cst_key <> TRIM(cst_key);

-- Data standardization check
SELECT DISTINCT
    cst_marital_status
FROM silver_crm_cust_info;


-- =====================================================
-- Checking silver_crm_prd_info
-- =====================================================

-- Check for NULLs or duplicate primary keys
-- Expectation: No rows returned
SELECT
    prd_id,
    COUNT(*) AS cnt
FROM silver_crm_prd_info
GROUP BY prd_id
HAVING cnt > 1 OR prd_id IS NULL;

-- Check for unwanted spaces in product name
-- Expectation: No rows returned
SELECT
    prd_nm
FROM silver_crm_prd_info
WHERE prd_nm <> TRIM(prd_nm);

-- Check for NULL or negative product cost
-- Expectation: No rows returned
SELECT
    prd_cost
FROM silver_crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data standardization check
SELECT DISTINCT
    prd_line
FROM silver_crm_prd_info;

-- Check invalid date ranges (start date > end date)
-- Expectation: No rows returned
SELECT *
FROM silver_crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_end_dt < prd_start_dt;


-- =====================================================
-- Checking silver_crm_sales_details
-- =====================================================

-- Check for invalid date ordering
-- Expectation: No rows returned
SELECT *
FROM silver_crm_sales_details
WHERE (sls_order_dt > sls_ship_dt AND sls_ship_dt IS NOT NULL)
   OR (sls_order_dt > sls_due_dt  AND sls_due_dt  IS NOT NULL);

-- Check data consistency: Sales = Quantity * Price
-- Expectation: No rows returned
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver_crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;


-- =====================================================
-- Checking silver_erp_cust_az12
-- =====================================================

-- Identify out-of-range birth dates
-- Expectation: Birthdates between 1924-01-01 and today
SELECT DISTINCT
    bdate
FROM silver_erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > CURDATE();

-- Data standardization check
SELECT DISTINCT
    gen
FROM silver_erp_cust_az12;


-- =====================================================
-- Checking silver_erp_loc_a101
-- =====================================================

-- Data standardization check
SELECT DISTINCT
    cntry
FROM silver_erp_loc_a101
ORDER BY cntry;


-- =====================================================
-- Checking silver_erp_px_cat_g1v2
-- =====================================================

-- Check for unwanted spaces
-- Expectation: No rows returned
SELECT *
FROM silver_erp_px_cat_g1v2
WHERE cat <> TRIM(cat)
   OR subcat <> TRIM(subcat)
   OR maintenance <> TRIM(maintenance);

-- Data standardization check
SELECT DISTINCT
    maintenance
FROM silver_erp_px_cat_g1v2;
