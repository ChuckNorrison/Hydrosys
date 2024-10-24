# Hydrosystem

The hydrosys4 project aims to create a platform for the raspberry pi which lets you easily control and record sensors data. 

Use actuators through the GPIO and play with analog by using external ADC the supported hardware and wiring can be found in the Documentation folder.

The platform is developed in python and is based on web server interface. The system can control the WiFi interface and works in Access point mode where to user can connect to. 

The webserver interface can be adjusted to support several purposes, the current development is used as automatic irrigation system. The GUI is made to support planning and conditional irrigation based on temperature and humidity, relays control the valve and pumps, the system also supports email notifications, cameras and video stream. Latest upgrade include possibility to mount camera over servo.

The software platform is based on a web interface where the webserver is running locally on the raspberry pi. The software is designed to be used with smartphone and to be reachable from internet without need of external servers or dynamic DNS. Every time the IP address is updated the system will send an email with relevant link as configured. 

More details can be found on the webpage https://hydrosysblog.wordpress.com/

![image](https://github.com/user-attachments/assets/481f820f-82e2-4f30-bfb0-a897d2679e94)

# Installation

For installation please follow the installation guide from here:

https://hydrosysblog.wordpress.com/configuration/

two installation methods are possible:

1) For easy installation it is possible to directly download the SD image from current relase

2) For a more traditional installation it is possible to download a bash installer 

```
wget https://raw.githubusercontent.com/Hydrosys4/Master/master/bash/install_hydrosys4.sh

sudo chmod u+x install_hydrosys4.sh

sudo ./install_hydrosys4.sh
```

# Access to the System

The system runs on a raspberry pi, which will act as access point per default. Wait a few seconds after the system is restarted, you will see a new wifi network.
Once connected to the wifi network, open the webbrowser and type the address indicated in the guide.

https://hydrosysblog.wordpress.com/configuration/


# Login

the login credential are:
Username: admin
Password: default

it is strongly suggested to modify the password.
