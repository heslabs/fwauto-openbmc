# 2025-12-26


4. Setup local console windows (IMPORTANT - This allows you to see FVP consoles):

   a) Establish SSH tunnel in background:
      ssh -f -N -L 5064:127.0.0.1:5064 -L 5065:127.0.0.1:5065 -L 5066:127.0.0.1:5066 -L 5067:127.0.0.1:5067 -L 4222:127.0.0.1:4222 -L 4223:127.0.0.1:4223 -o StrictHostKeyChecking=no nicetech@122.116.228.96
      Password: rpi5demo

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
