
Host PC
* IP: 122.116.228.96
* Username: fvp
* Password: demo123@

Pleases connect the host PC and execute the following tasks
```
sshpass -p demo123@ ssh -X fvp@122.116.228.96
```

Navigate to the project folder and launch the setup script.
```
cd ~/openbmc/fvp-poc
./setup-tap-fixed.sh
./cleanup-fvp.sh
```

Navigate to the project folder and launch the script and show the terminal.
```
cd ~/openbmc/fvp-poc
./run-rdv3.sh
```

Waiting until login prompt and login with the following credential 
username: root
password: 0penBmc

Please fix the errors if any

