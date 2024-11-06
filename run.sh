#!/bin/bash

# Reset the SECONDS variable to track execution time
SECONDS=0

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Check if required variables are set
if [[ -z "$SQLSERVER_HOST" || -z "$SQLSERVER_USER" || -z "$SQLSERVER_PASSWORD" || -z "$SQLSERVER_PORT" || -z "$SQLSERVER_DB" ]]; then
    echo "Error: One or more environment variables are not set."
    exit 1
fi

# Set the SQLCMD password parameter to avoid password prompts
export SQLCMDPASSWORD=$SQLSERVER_PASSWORD

# Create or clear the output log file
LOG_FILE="output.log"
> $LOG_FILE

# Run the SQL files and redirect output to the log file
{
    echo "Running SQL files..."
    sqlcmd -S $SQLSERVER_HOST,$SQLSERVER_PORT -U $SQLSERVER_USER -P $SQLSERVER_PASSWORD -d $SQLSERVER_DB -i sql/USR_REP_PaymentsData_modified.sql
    sqlcmd -S $SQLSERVER_HOST,$SQLSERVER_PORT -U $SQLSERVER_USER -P $SQLSERVER_PASSWORD -d $SQLSERVER_DB -i sql/dummydata2.sql
    sqlcmd -S $SQLSERVER_HOST,$SQLSERVER_PORT -U $SQLSERVER_USER -P $SQLSERVER_PASSWORD -d $SQLSERVER_DB -i sql/USR_REP_PromptPaymentsReport_All_modified.sql
    sqlcmd -S $SQLSERVER_HOST,$SQLSERVER_PORT -U $SQLSERVER_USER -P $SQLSERVER_PASSWORD -d $SQLSERVER_DB -i sql/USR_VW_PromptPaymentsReport_modified.sql
    sqlcmd -S $SQLSERVER_HOST,$SQLSERVER_PORT -U $SQLSERVER_USER -P $SQLSERVER_PASSWORD -d $SQLSERVER_DB -i sql/USR_Refill_REP_Schema_PromptPay_ToOptimise_modified.sql
    sqlcmd -S $SQLSERVER_HOST,$SQLSERVER_PORT -U $SQLSERVER_USER -P $SQLSERVER_PASSWORD -d $SQLSERVER_DB -i sql/execute_sp.sql

} 2>&1 | tee -a $LOG_FILE

# Check if the SQL files executed successfully
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "SQL files executed successfully. Check output.log for details." | tee -a $LOG_FILE
else
    echo "Error executing SQL files. Check output.log for details." | tee -a $LOG_FILE
    exit 1
fi

# Print total execution time
echo "Total execution time: $SECONDS seconds" | tee -a $LOG_FILE