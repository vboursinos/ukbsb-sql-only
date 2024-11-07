## Running SQL Queries
### Run script command for query execution
```
bash ./run.sh execute
```

### Run script command for query result validation
```
bash ./run.sh validate
```

### Run script command for query execution and clean up
```
bash ./run.sh execute clean
```

### Run script command for query result validation and clean up
```
bash ./run.sh validate clean
```

## sqlcmd Installation

Steps to Install sqlcmd on Ubuntu (20.04 or later)
1. Download and Install the Microsoft SQL Server Tools Repository
   First, you need to install the Microsoft repository key and repository configuration manually:

Add the Microsoft GPG key:

```
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
```
Add the Microsoft SQL Server tools repository:

For Ubuntu 20.04, you can directly add the repository using this command:

```
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/mssql-tools/ubuntu/20.04/prod stable main" > /etc/apt/sources.list.d/mssql-tools.list'
```

2. Install sqlcmd
   
Now that the repository is added, you can install the SQL Server command-line tools:

Update the apt package list:
```
sudo apt-get update
```

Install mssql-tools:

```
sudo apt-get install mssql-tools unixodbc-dev
```
This command installs both sqlcmd and the necessary ODBC libraries (unixodbc-dev).

3. Verify the Installation

After installing, verify that sqlcmd is installed by running:

```
sqlcmd -?
```
If everything is working, you should see the usage instructions for sqlcmd.

4. Add sqlcmd to PATH (Optional)

If you want to be able to run sqlcmd from anywhere without specifying the full path, you can add it to your PATH.

Run the following command:

```
echo "export PATH=\$PATH:/opt/mssql-tools/bin" >> ~/.bashrc
source ~/.bashrc
```