## You> Please use English for the conversation
## You> Please read the file "openbmc-run.md" and execute the tasks

Please help to execute the following tasks on the remote PC server 
Connect to the SSH and serial console to view real-time boot messages

Remote PC server information:
* Host IP: 192.168.52.91
* Username: auto
* Password: demo123@


## Execution steps:

0. Connect the remote PC server
```
sshpass -p demo123@ ssh auto@192.168.52.91 -X
```

1. Setup the TAP interafce
```
cd ~/openbmc/fvp && ./cleanup-fvp.sh
cd ~/openbmc/fvp && ./cleanup-tap.sh
cd ~/openbmc/fvp && ./setup-tap-fixed.sh
```

2. Launch FVP and waiting for completing the booting sequence 
```
cd ~/openbmc/fvp && nohup ./run.sh -m /home/auto/openbmc/FVP_RD_V3_R1/models/Linux64_GCC-9.3/FVP_RD_V3_R1
```

3. Wait for booting sequence to login promots (polling, max 5 minutes):
```			
for i in {1..60}; do
    sshpass -p "0penBmc" ssh -p 4222 -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@127.0.0.1 "echo BMC_READY"' 2>/dev/null && break
    echo "Waiting for BMC... ($i/60)"
    sleep 5
done
```

4. Once BMC is ready, perform verification:

a) SSH to BMC and restart MCTP service:
```
sshpass -p "0penBmc" ssh -p 4222 -o StrictHostKeyChecking=no root@127.0.0.1 "systemctl restart mctpd.service"
```

b) Wait for MCTP service to start:
```
sleep 5
```

c) Test PLDM:
```
sshpass -p "0penBmc" ssh -p 4222 -o StrictHostKeyChecking=no root@127.0.0.1 "pldmtool platform GetPDR -d 1"
```

d) Test Redfish on the remote host:
```
curl -k -u root:0penBmc https://127.0.0.1:4223/redfish/v1/
```

5. Setup local console windows (IMPORTANT - This allows you to see FVP consoles):

a) Establish SSH tunnel in background:
```
ssh -f -N -L 5064:127.0.0.1:5064 -L 5065:127.0.0.1:5065 -L 5066:127.0.0.1:5066 -L 5067:127.0.0.1:5067 -L 4222:127.0.0.1:4222 -L 4223:127.0.0.1:4223 -o StrictHostKeyChecking=no auto@192.168.52.91
Password: demo123@
```

b) Open console windows using xterm (or gnome-terminal):
# BMC Console
xterm -T "BMC Console (Port 5065)" -e "telnet localhost 5065" &

# Host Console
xterm -T "Host Console (Port 5064)" -e "telnet localhost 5064" &

# Additional Console 2
xterm -T "Console 2 (Port 5066)" -e "telnet localhost 5066" &

# Additional Console 3
xterm -T "Console 3 (Port 5067)" -e "telnet localhost 5067" &

c) Alternative: Use gnome-terminal if xterm is not available:
gnome-terminal --title="BMC Console" -- telnet localhost 5065 &
gnome-terminal --title="Host Console" -- telnet localhost 5064 &
gnome-terminal --title="Console 2" -- telnet localhost 5066 &
gnome-terminal --title="Console 3" -- telnet localhost 5067 &

d) Verify SSH tunnel is working:
ssh -p 4222 root@localhost "cat /etc/os-release"
Password: 0penBmc


6. Verification success criteria:

* FVP started successfully on remote host
* BMC SSH connection successful (see BMC_READY)
* mctpd.service restart successful
* Redfish API returns JSON response
* SSH tunnel established (ports 4222, 4223, 5064-5067 forwarded)
* Console windows opened on local machine showing BMC/Host output


7. Summary

* Create the readme.md for the summary of executed tasks
* Create the organized scripts for repeating the full  execution process 


