#!/bin/bash
# This script was created by Giridharan for the purpose of creating 
# HANA database in a docker container over NFS mounted filesystems

#Getting the input parameters
echo "Welcome to the HANA-Docker DB installtion Script"
echo "------------------------------------------------"
echo ""
echo "List of pre-requisites to complete"
echo " 1) Prepare an NFS server"
echo " 2) Create NFS export mounts for /hana/shared, /hana/data, /hana/log, /usr/sap, /var/lib/hdb"
echo " 3) Install docker engine and docker compose in the host to execute this script"
echo " 4) Decide and be ready with the hostname, SID and instance number that you want to set for hana"
echo " 5) Download the SAP HANA Database Platform Edition from market place and extract the package in local location"
echo " 6) Prepare an empty working directory for the script to execute"
echo " 7) Make sure the user who is executing have elevated permissions to change kernel parameters and access to HANA installation package"
echo " 8) To execute this script you need to be either root or start script with sudo command"
echo ""
read -p "Do you agree that pre-requisites met and want to proceed? (yes/no) " yn
case $yn in
	yes ) echo ok, we will proceed;;
	no ) echo exiting...;
		exit;;
	* ) echo invalid response;
		exit 1;;
esac
clear
echo "---------------------------------------------------"
echo "Choose the required option that you want to proceed"
echo " 1.HANA Docker Container Deployment"
echo " 2.Existing HANA Docker Container Run"
echo "   Note:- Option2 can be selected after successfull execution of Option 1"
echo ""
read -p "select the option  (1 or 2): " -n 1 -r inp
case ${inp} in
        1)echo ""
echo ""
echo "-------------------------------------------------"
echo "Please prodive the input values as required below:"
echo ""
echo "!!CAUTION!!! input values does not have validation, please be cautious while responding"
echo "---------------------------------------------------------------------------------------"
echo "hostname to be set for HANA ?"
read HSTNM
echo ""
echo "SID of HANA to be set ?:"
read HSID
echo ""
echo "Instance number of HANA DB to set ?:"
read HNR
echo ""
echo "location where HANA package installer is extracted ?"
read HLOC
echo ""
echo "Input Master password for HANA the password should contain"
echo "1 upper case, 1 lower case,1 number, 1 special char and min. 8 char length"
echo "-----------------------------------------------------------------"
echo "password:"
read -s HPASS
echo ""
echo "Please enter the hostname or ip address of the NFS server"
read HNFSS
echo ""
echo "Please enter the NFS server mount location for /hana/shared"
read HMHSH
echo ""
echo "Please enter the NFS server mount location for /hana/data"
read HMHD
echo ""
echo "Please enter the NFS server mount location for /hana/log"
read HMHL
echo ""
echo "Please enter the NFS server mount location for /usr/sap"
read HMHUS
echo ""
echo "Please enter the NFS server mount location for /var/lib/hdb"
read HMHVL
echo ""
HSIDL="$(echo "$HSID" | tr '[:upper:]' '[:lower:]')"
rm ./input_val > /dev/null
echo "HSTNM=$HSTNM" >> input_val
echo "HSID=$HSID" >> input_val
echo "HNR=$HNR" >> input_val
echo "HLOC=$HLOC" >> input_val
echo "HNFSS=$HNFSS" >> input_val
echo "HMHSH=$HMHSH" >> input_val
echo "HMHD=$HMHD" >> input_val
echo "HMHL=$HMHL" >> input_val
echo "HMHUS=$HMHUS" >> input_val
echo "HMHVL=$HMHVL" >> input_val
echo "HSIDL=$HSIDL" >> input_val
echo ""
echo "HANA-Docker deployment will proceed:"
echo "------------------------------------"
echo ""
echo "!!Note!! The script will update below kernel paramters"
echo "fs.file-max=20000000"
echo "fs.aio-max-nr=262144"
echo "vm.memory_failure_early_kill=1"
echo "vm.max_map_count=135217728"
echo "net.ipv4.ip_local_port_range=60000 65535"
echo "Disable transparent Huge pages"
echo "Add docker overlay storage driver"
echo ""
read -p "Do you wish to proceed? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
	(
#Updating Kernel parameters
tee -a /etc/sysctl.conf << END >/dev/null
fs.file-max=20000000
fs.aio-max-nr=262144
vm.memory_failure_early_kill=1
vm.max_map_count=135217728
net.ipv4.ip_local_port_range=60000 65535
END
sysctl -p
echo never > /sys/kernel/mm/transparent_hugepage/enabled
tee -a /etc/docker/daemon.json <<END >/dev/null
{
"storage-driver": "overlay2"
}
END
sleep 2
systemctl restart docker.service
sleep 3
echo ""
echo "Kernel Parameters Updated"
echo ""
)
elif [[ $REPLY =~ ^[Nn]$ ]]
then
	(
echo ""	
echo "ok, will Proceed without updating kernel parameters"
echo ""
)
else
	(
echo ""	
echo "invalid input, exiting ......"
exit
)
fi

$HLOC/SAP_HANA_DATABASE/hdblcm --action=install --dump_configfile_template=hana_install.cfg
sed -i "s/master_password=/master_password=$HPASS/g" hana_install.cfg
sed -i "s/^hostname=.*/hostname=$HSTNM/g" hana_install.cfg
sed -i 's/^use_master_password=.*/use_master_password=y/g' hana_install.cfg
sed -i 's/components=/components=server/g' hana_install.cfg
sed -i 's/ignore=/ignore=check_signature_file/g' hana_install.cfg
sed -i "s/sid=/sid=$HSID/g" hana_install.cfg
#sed -i 's/^hostname=.*/#&\
#hostname=$HSTNM/' hana_install.cfg
sed -i "s/number=/number=$HNR/g" hana_install.cfg
echo ""
echo "------------------------------------------------------------------------------------------------------------------------"
echo "Config file generated with recieved inputs, If you still want to modify HANA installation parameters before deployment"
echo "Dont close this screen, open new terminal and navigate to this folder. You can find a file named !! hana_install.cfg !!"
echo "Modify the required variables for HANA installation in hana_install.cfg and proceed (Note: Do not modify hostname here )"
echo "------------------------------------------------------------------------------------------------------------------------"
read -p "All modifications completed?, Do you want to proceed? (y/n):" -n 1 -r  ny
case $ny in
        y|Y ) echo""
	      echo "ok, we will proceed";;
        n|N ) echo ""
	      echo exiting...;
              exit;;
        * )   echo ""
	      echo invalid response;
              exit 1;;
esac
echo ""
#create an execution script
tee -a ./hana_deploy.sh << END >/dev/null
#!/bin/bash 
zypper update -y 
zypper --non-interactive install --replacefiles which hostname expect net-tools net-tools-deprecated iputils wget vim iproute2 unrar less tar gzip uuidd tcsh libaio insserv-compat libatomic1 libnuma1 sudo libltdl7 unzip 
mkdir /run/uuidd && chown uuidd /var/run/uuidd && /usr/sbin/uuidd 
echo "(hostname -I | awk '{print 1}')     (hostname)" >> /etc/hosts 
cd /hana_inst/SAP_HANA_DATABASE 
./hdblcm --action=install --configfile=/hana_media/hana_install.cfg -b
cp /etc/passwd /hana_media/
cp /etc/group /hana_media/
END
chmod +x hana_deploy.sh
sed -i 's/(hostname/$(hostname/g' hana_deploy.sh
sed -i 's/1}/$1}/g' hana_deploy.sh


tee -a ./hana_run.sh << END >/dev/null
#!/bin/bash 
zypper update -y 
zypper --non-interactive install --replacefiles which hostname expect net-tools net-tools-deprecated iputils wget vim iproute2 unrar less tar gzip uuidd tcsh libaio insserv-compat libatomic1 libnuma1 sudo libltdl7 unzip 
mkdir /run/uuidd && chown uuidd /var/run/uuidd && /usr/sbin/uuidd 
echo "(hostname -I | awk '{print 1}')     (hostname)" >> /etc/hosts 
su - (HSID)adm -c "HDB start"
END
chmod +x hana_run.sh
sed -i 's/(hostname/$(hostname/g' hana_run.sh
sed -i 's/1}/$1}/g' hana_run.sh
sed -i "s/(HSID)/$HSIDL/g" hana_run.sh

echo "root:x:0:0:root:/root:/bin/bash" > passwd
tee ./group << END >/dev/null
root:x:0:
shadow:x:15:
trusted:x:42:
users:x:100:
kmem:x:499:
lock:x:498:
tty:x:5:
utmp:x:497:
audio:x:496:
cdrom:x:495:
dialout:x:494:
disk:x:493:
input:x:492:
lp:x:491:
render:x:490:
sgx:x:489:
tape:x:488:
video:x:487:
END
chmod 644 passwd group
tee -a ./dc_hana_deploy.yml << END >/dev/null
version: "3.8"
services:
 sap-hana:
    hostname: $HSTNM
    image: opensuse/leap:latest
    container_name: sap-hana
    network_mode: host
    environment:
       - LANG=en_US.UTF-8
    volumes:
      - type: volume
        source: sap_usr
        target: /usr/sap
        volume:
          nocopy: true
      - type: volume
        source: hana_shared
        target: /hana/shared
        volume:
          nocopy: true
      - type: volume
        source: hana_data
        target: /hana/data
        volume:
          nocopy: true
      - type: volume
        source: hana_log
        target: /hana/log
        volume:
          nocopy: true
      - type: volume
        source: var_hdb
        target: /var/lib/hdb
        volume:
          nocopy: true
      - ./:/hana_media
      - $HLOC/SAP_HANA_DATABASE:/hana_inst/SAP_HANA_DATABASE
    command: /bin/sh -c "/hana_media/hana_deploy.sh && /bin/bash"
    stdin_open: true
    tty: true
volumes:
  sap_usr:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHUS"
  hana_shared:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHSH"
  hana_data:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHD"
  hana_log:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHL"
  var_hdb:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHVL"
END
docker-compose -f dc_hana_deploy.yml up --detach
sleep 5
echo ""
echo "------------------------------------------------------"
echo "HANA-Docker container Deployment executed Successfully"
echo "Docker compose running in detached mode"
echo "------------------------------------------------------------"
echo "To view the Docker container logs execute the below command:"
echo "docker container logs -f sap-hana"
echo "------------------------------------------------------------"
exit 0
;;

     2) echo ""
INFIL=./input_val
if [[ -f "$INFIL" ]]; then
    echo "$INFIL Already exists."
else
echo ""
echo "copying /etc/passwd file from container..."
echo "Please prodive the input values as required below"
echo ""
echo "!!CAUTION!!! input values does not have validation, please be cautious while responding"
echo "---------------------------------------------------------------------------------------"
echo "hostname to be set for HANA ?"
read HSTNM
echo ""
echo "SID of HANA to be set ?:"
read HSID
echo ""
echo "Instance number of HANA DB to set ?:"
read HNR
echo ""
echo "location where HANA package installer is extracted ?"
read HLOC
echo ""
echo "Please enter the hostname or ip address of the NFS server"
read HNFSS
echo ""
echo "Please enter the NFS server mount location for /hana/shared"
read HMHSH
echo ""
echo "Please enter the NFS server mount location for /hana/data"
read HMHD
echo ""
echo "Please enter the NFS server mount location for /hana/log"
read HMHL
echo ""
echo "Please enter the NFS server mount location for /usr/sap"
read HMHUS
echo ""
echo "Please enter the NFS server mount location for /var/lib/hdb"
read HMHVL
echo ""
HSIDL="$(echo "$HSID" | tr '[:upper:]' '[:lower:]')"
echo "HSTNM=$HSTNM" >> input_val
echo "HSID=$HSID" >> input_val
echo "HNR=$HNR" >> input_val
echo "HLOC=$HLOC" >> input_val
echo "HNFSS=$HNFSS" >> input_val
echo "HMHSH=$HMHSH" >> input_val
echo "HMHD=$HMHD" >> input_val
echo "HMHL=$HMHL" >> input_val
echo "HMHUS=$HMHUS" >> input_val
echo "HMHVL=$HMHVL" >> input_val
echo "HSIDL=$HSIDL" >> input_val
echo ""
fi
FILE1=./passwd
if [[ -f "$FILE1" ]]; then
    echo "$FILE1 Already exists."
else
echo ""	
echo "copying /etc/passwd file from container..."
echo ""
docker cp sap-hana:/etc/passwd passwd
fi
FILE2=./group
if [[ -f "$FILE2" ]]; then
    echo "$FILE2 Already exists."
else
echo ""
echo "copying /etc/group file from container..."
echo ""
docker cp sap-hana:/etc/group group
fi
source ./input_val
tee -a ./dc_hana_run.yml <<END >/dev/null
version: "3.8"
services:
 sap-hana:
    hostname: $HSTNM
    image: opensuse/leap:latest
    container_name: sap-hana
    network_mode: host
    environment:
       - LANG=en_US.UTF-8
    volumes:
      - type: volume
        source: sap_usr
        target: /usr/sap
        volume:
          nocopy: true
      - type: volume
        source: hana_shared
        target: /hana/shared
        volume:
          nocopy: true
      - type: volume
        source: hana_data
        target: /hana/data
        volume:
          nocopy: true
      - type: volume
        source: hana_log
        target: /hana/log
        volume:
          nocopy: true
      - type: volume
        source: var_hdb
        target: /var/lib/hdb
        volume:
          nocopy: true
      - ./:/hana_media
      - ./passwd:/etc/passwd
      - ./group:/etc/group
    command: /bin/sh -c "/hana_media/hana_run.sh && /bin/bash"
    stdin_open: true
    tty: true
volumes:
  sap_usr:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHUS"
  hana_shared:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHSH"
  hana_data:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHD"
  hana_log:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHL"
  var_hdb:
    driver_opts:
      type: "nfs"
      o: "addr=$HNFSS,nolock,soft,rw"
      device: ":$HMHVL"
END

docker-compose -f dc_hana_run.yml up --detach
echo ""
echo "-----------------------------------------------"
echo "HANA-Docker container run executed Successfully"
echo "Docker compose running in detached mode"
echo "-----------------------------------------------------------"
echo "To view the Docker container logs execute the below command:"
echo ""docker container logs -f sap-hana""
echo "---------------------------------------------"
exit 0
;;
     *)echo ""
       echo "Invalid input, exiting ...."
       exit 1
esac
