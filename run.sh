#!/bin/bash

# Reset the SECONDS variable to track execution time
SECONDS=0
LOG_FILE="execution_log.txt"  # Path to log file
ERROR_LOG="error_log.txt"     # Separate log for errors

# Clear previous log files
> "$LOG_FILE"
> "$ERROR_LOG"

# Exit immediately on error, and handle cleanup with trap
set -e
trap 'echo "An error occurred. Check logs for details."; exit 1' ERR

# Check if at least one argument is passed
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 {execute} {validate} {clean}" | tee -a "$LOG_FILE"
    exit 1
fi

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Check if required variables are set
if [[ -z "$SQLSERVER_HOST" || -z "$SQLSERVER_USER" || -z "$SQLSERVER_PASSWORD" || -z "$SQLSERVER_PORT" || -z "$SQLSERVER_DB" ]]; then
    echo "Error: One or more environment variables are not set." | tee -a "$LOG_FILE"
    exit 1
fi

# Set the SQLCMD password parameter to avoid password prompts
export SQLCMDPASSWORD=$SQLSERVER_PASSWORD

# Array of setup SQL files to execute
SETUP_SQL_FILES=("sql/USR_REP_PaymentsData_modified.sql" "sql/dummydata2.sql" "sql/USR_REP_PromptPaymentsReport_All_modified.sql" "sql/USR_VW_PromptPaymentsReport_modified.sql" "sql/USR_Refill_REP_Schema_PromptPay_ToOptimise_modified.sql" "sql/execute_sp.sql")

# Flag variables to track the selected modes
EXECUTE=false
VALIDATE=false
CLEAN=false

# Parse flags
for arg in "$@"; do
    case $arg in
        execute)
            EXECUTE=true
            ;;
        validate)
            VALIDATE=true
            ;;
        clean)
            CLEAN=true
            ;;
        *)
            echo "Invalid argument: $arg" | tee -a "$LOG_FILE"
            echo "Usage: $0 {execute} {validate} {clean}" | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac
done

# Execute SQL files if the execute flag is set
if [ "$EXECUTE" == true ] || [ "$VALIDATE" == true ]; then
    echo "Executing setup SQL files..." | tee -a "$LOG_FILE"
    for SQL_FILE in "${SETUP_SQL_FILES[@]}"; do
        echo "Executing SQL file: $SQL_FILE" | tee -a "$LOG_FILE"

        # Execute the SQL file and check if it fails
        if ! sqlcmd -S "$SQLSERVER_HOST,$SQLSERVER_PORT" -U "$SQLSERVER_USER" -P "$SQLSERVER_PASSWORD" -d "$SQLSERVER_DB" -i "$SQL_FILE" | tee -a "$LOG_FILE"; then
            echo "Error executing $SQL_FILE. Exiting." | tee -a "$LOG_FILE"
            exit 1
        else
            echo "Successfully executed $SQL_FILE." | tee -a "$LOG_FILE"
        fi
    done
fi

# If the mode is 'validate', execute and validate the stored procedure output
if [ "$VALIDATE" == true ]; then
    VALIDATION_RESULT="validation_results.txt"
    EXPECTED_TOTAL_ROWS=7
    EXPECTED_TOTAL_COLUMNS=40

    # Execute SQL query and capture the output into a file
    FINAL_LOG="final_output.log"
    echo "Executing stored procedure and capturing output..." | tee -a $LOG_FILE
    sqlcmd -S "$SQLSERVER_HOST,$SQLSERVER_PORT" -U "$SQLSERVER_USER" -P "$SQLSERVER_PASSWORD" -d "$SQLSERVER_DB" -Q "
    USE StagingFinance;
    EXEC dbo.USR_Refill_REP_Schema_PromptPay_ToOptimise;
    SELECT * FROM dbo.USR_REP_PromptPaymentsReport_All;
    " > "$FINAL_LOG" 2>&1

    # Check if the SQL command was successful
    if [ $? -eq 0 ]; then
        echo "Stored procedure executed. Results saved to $FINAL_LOG." | tee -a $LOG_FILE
    else
        echo "Error executing stored procedure. Check $FINAL_LOG for details." | tee -a $LOG_FILE
        exit 1
    fi

    # Count the total rows and columns in the result file
    TOTAL_ROWS=$(wc -l < "$FINAL_LOG")
    TOTAL_COLUMNS=$(sed -n '4p' "$FINAL_LOG" | tr -s ' ' '\n' | wc -l)

    # Save the row and column counts into the validation result file
    echo "Total Rows: $TOTAL_ROWS" > "$VALIDATION_RESULT"
    echo "Total Columns: $TOTAL_COLUMNS" >> "$VALIDATION_RESULT"

    echo "Total Rows: $TOTAL_ROWS"
    echo "Total Columns: $TOTAL_COLUMNS"
    echo "Validation results saved to $VALIDATION_RESULT." | tee -a $LOG_FILE

    # Compare the actual values with the expected values
    if [ "$EXPECTED_TOTAL_ROWS" -eq "$TOTAL_ROWS" ] && [ "$EXPECTED_TOTAL_COLUMNS" -eq "$TOTAL_COLUMNS" ]; then
        echo "Validated: The validation results match." | tee -a $LOG_FILE
    else
        echo "Validation failed: The validation results do not match." | tee -a $LOG_FILE
        exit 1
    fi
fi



# If the mode is 'clean', drop all tables, stored procedures, views, and functions in the dbo schema
if [ "$CLEAN" == true ]; then
    echo "Dropping all tables, views, stored procedures, and functions in the dbo schema..." | tee -a $LOG_FILE

    # Generate the SQL command to drop all tables, views, stored procedures, and functions in the dbo schema
    DROP_SQL=$(sqlcmd -S "$SQLSERVER_HOST,$SQLSERVER_PORT" -U "$SQLSERVER_USER" -P "$SQLSERVER_PASSWORD" -d "$SQLSERVER_DB" -Q "
    DECLARE @sql NVARCHAR(MAX) = N'';
    -- Drop tables in dbo schema
    SELECT @sql += 'DROP TABLE dbo.' + TABLE_NAME + ';' + CHAR(13)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo';
    -- Drop views in dbo schema
    SELECT @sql += 'DROP VIEW dbo.' + TABLE_NAME + ';' + CHAR(13)
    FROM INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = 'dbo';
    -- Drop stored procedures in dbo schema
    SELECT @sql += 'DROP PROCEDURE dbo.' + SPECIFIC_NAME + ';' + CHAR(13)
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'PROCEDURE';
    -- Drop functions in dbo schema
    SELECT @sql += 'DROP FUNCTION dbo.' + SPECIFIC_NAME + ';' + CHAR(13)
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_TYPE = 'FUNCTION';
    EXEC sp_executesql @sql;
    ")

    # Execute the generated SQL to drop all dbo tables, views, stored procedures, and functions
    sqlcmd -S "$SQLSERVER_HOST,$SQLSERVER_PORT" -U "$SQLSERVER_USER" -P "$SQLSERVER_PASSWORD" -d "$SQLSERVER_DB" -Q "$DROP_SQL" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "All tables, views, stored procedures, and functions in the dbo schema dropped successfully." | tee -a $LOG_FILE
    else
        echo "Error dropping objects in the dbo schema." | tee -a $LOG_FILE
        exit 1
    fi
fi

# Print total execution time
echo "Total execution time: $SECONDS seconds" | tee -a $LOG_FILE
