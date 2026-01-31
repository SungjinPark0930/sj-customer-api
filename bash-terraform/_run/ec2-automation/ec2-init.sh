#!/bin/bash

export AUTOMATION_HOME="/root"
export LOG_NAME="init.log"
export SSSD_CONF="/etc/sssd/sssd.conf"
export SYSTEM_AUTH="/etc/pam.d/system-auth"
export PASSWORD_AUTH="/etc/pam.d/password-auth"
export SUDO="/etc/pam.d/sudo"
export SERVER_IP_ADDRESS=`ifconfig | grep 10.xxxx | awk -F " " '{ print $2 }'`

# Create SWAP Memory
sudo fallocate -l 2G /swapfile
sudo dd if=/dev/zero of=/swapfile bs=1024 count=2097152

sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
sudo swapon --show
sudo free -h
echo "done"

# Mount EBS volume
export SERVICE_ACCOUNT="xxxx"
export DEVICE_NAME="nvme1n1"
export DIRECTORY_NAME="xxxx"

useradd $SERVICE_ACCOUNT
mkdir /$DIRECTORY_NAME
sleep 2s

mkfs -t ext4 /dev/$DEVICE_NAME
sleep 6s

export UUID_NAME=`ls /dev/disk/by-uuid -lt | grep $DEVICE_NAME | awk -F " " '{ print $9 }'`
sed -i '/$UUID_NAME/d' /etc/fstab
sed -i '/$DIRECTORY_NAME/d' /etc/fstab

echo "==== Before Add Device ===="
cat /etc/fstab
echo "UUID=$UUID_NAME /$DIRECTORY_NAME ext4 defaults 0 0" >> /etc/fstab
echo "==== After Add Device ===="
cat /etc/fstab
echo "===================="
mount -a

sleep 2s
chown -R $SERVICE_ACCOUNT:$SERVICE_ACCOUNT /$DIRECTORY_NAME
df -h | grep /$DIRECTORY_NAME
ls -ld /$DIRECTORY_NAME


# Remove AD Join if it joined previously
realm leave xxxx

#echo -e "Memory is 1GB? (If Memory is 0.5 GB then it does NOT work. Enter If your Memory is OK.) : \c"
#read -r MEMORY_CHECK
echo -e "Hostname Input: \c"
read -r HOSTNAME_INPUT
export HOSTNAME_UPPER=`echo $HOSTNAME_INPUT | tr '[a-z]' '[A-Z]'`

echo -e "Select DEV or PROD : \c"
read -r SELECT_ENV
export SELECT_ENV_UPPER=`echo $SELECT_ENV | tr '[a-z]' '[A-Z]'`

echo "" > $AUTOMATION_HOME/$LOG_NAME
echo "호스트네임은 $HOSTNAME_UPPER 이고,IP은 $SERVER_IP_ADDRESS 입니다. 또한 환경은 $SELECT_ENV_UPPER 입력 했습니다." >> $AUTOMATION_HOME/$LOG_NAME

sleep 2s

echo "-------------------------------------"  >> $AUTOMATION_HOME/$LOG_NAME
echo "리눅스 색상 변경합니다." >> $AUTOMATION_HOME/$LOG_NAME

if [ $SELECT_ENV_UPPER = PROD ]; then 
    echo 'PS1="\[\033[31m\][\u@\h \W]# \[\033[00m\]"' > /etc/profile.d/custom_PS1.sh
    echo "설정된 PROD 색상으로 변경 됐습니다"
    elif [ $SELECT_ENV_UPPER = DEV ]; then
    echo 'PS1="\[\033[32m\][\u@\h \W]# \[\033[00m\]"' > /etc/profile.d/custom_PS1.sh
    echo "설정된 DEV 색상으로 변경 됐습니다"
else
    echo "Error"
    exit 1
fi

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "호스트명을 변경 합니다."

hostnamectl set-hostname "$HOSTNAME_UPPER"

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "hosts 파일을 수정 합니다."

# Delete the existing xxxx
sed -i '/xxxx/d' /etc/hosts
sed -i '/xxxx/d' /etc/hosts
echo "$SERVER_IP_ADDRESS $HOSTNAME_UPPER.xxxx $HOSTNAME_UPPER.xxxx $HOSTNAME_UPPER" >> /etc/hosts

cat /etc/hosts  >> $AUTOMATION_HOME/$LOG_NAME

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "미사용 계정(lp,nobody, nfsnobody) 삭제 합니다."  >> $AUTOMATION_HOME/$LOG_NAME

userdel lp
userdel nobody
userdel nfsnobody

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"
echo "/etc/login.defs 설정 파일을 수정 합니다" >> $AUTOMATION_HOME/$LOG_NAME

sudo  sed -i 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/' /etc/login.defs
sudo  sed -i 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS\t7/' /etc/login.defs
sudo  sed -i 's/PASS_MIN_LEN\t5/PASS_MIN_LEN\t8/' /etc/login.defs
sudo  sed -i 's/PASS_WARN_AGE\t7/PASS_WARN_AGE\t7/' /etc/login.defs
sudo  sed -i 's/UMASK           077/UMASK           022/' /etc/login.defs 

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"
echo "수정된 파일 확인"  >> $AUTOMATION_HOME/$LOG_NAME

grep PASS_MAX_DAYS /etc/login.defs | grep -v '^#' | grep '^PASS_MAX_DAYS'
grep PASS_MIN_DAYS /etc/login.defs | grep -v '^#' | grep '^PASS_MIN_DAYS'
grep PASS_MIN_LEN /etc/login.defs | grep -v '^#' | grep '^PASS_MIN_LEN'
grep PASS_WARN_AGE /etc/login.defs | grep -v '^#' | grep '^PASS_WARN_AGE'
grep UMASK /etc/login.defs | grep -v '^#' | grep '^UMASK'

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"
echo "/etc/ssh/banner 파일을 생성합니다" >> $AUTOMATION_HOME/$LOG_NAME

touch /etc/ssh/banner

echo -e "Access to this computer or network system is limited to corporate authorized activity only. 
Any attempted unauthorized access, use, or  modification is expressly prohibited. 
Unauthorized users may face criminal or civil penalties\n 
** All computer or network access may be monitored and recorded. **\n
If monitoring reveals possible evidence of criminal activities, these records may be provided to law enforcement." > /etc/ssh/banner

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "/etc/ssh/sshd_config 파일을 생성합니다" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 180/' /etc/ssh/sshd_config
sed -i 's/#Banner none/Banner \/etc\/ssh\/banner/' /etc/ssh/sshd_config

echo "==== Set a session timeout ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Set a session timeout ===="
sed -i '/TMOUT/d' /etc/profile
echo "TMOUT=300" >> /etc/profile

echo $TMOUT >> $AUTOMATION_HOME/$LOG_NAME

grep Port /etc/ssh/sshd_config  | grep -v '^#' | grep '^Port'
grep PermitRootLogin /etc/ssh/sshd_config  | grep -v '^#' | grep '^PermitRootLogin'
grep PermitEmptyPasswords /etc/ssh/sshd_config  | grep -v '^#' | grep '^PermitEmptyPasswords'
grep PasswordAuthentication /etc/ssh/sshd_config  | grep -v '^#' | grep '^PasswordAuthentication'
grep ClientAliveInterval /etc/ssh/sshd_config  | grep -v '^#' | grep '^ClientAliveInterval'
grep Banner /etc/ssh/sshd_config  | grep -v '^#' | grep '^Banner'

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"
echo "그룹 추가 & su 권한 부여합니다." >> $AUTOMATION_HOME/$LOG_NAME

sed -i '/\-Admin/d' /etc/sudoers
sed -i '/\-ADMIN/d' /etc/sudoers

sudo sed -i -r "107s/.*/\%wheel  ALL=(ALL)       ALL\n/g" /etc/sudoers
sudo sed -i -r "109s/.*/\%xxxxx\tALL=(ALL) ALL\n/g" /etc/sudoers
sudo sed -i -r "110s/.*/\%$HOSTNAME_UPPER\tALL=(ALL) ALL\n/g" /etc/sudoers

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"
echo "KST 변경"  >> $AUTOMATION_HOME/$LOG_NAME

mv /etc/localtime /etc/localtime_org  
ln -s /usr/share/zoneinfo/Asia/Seoul /etc/localtime

date >> $AUTOMATION_HOME/$LOG_NAME

echo "-------------------------------------" >> $AUTOMATION_HOME/$LOG_NAME
echo "-------------------------------------"

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== dnf install  ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== dnf install  ===="
dnf install -y realmd oddjob oddjob-mkhomedir sssd adcli samba
dnf list | egrep '(realmd|oddjob|oddjob-mkhomedir|sssd|adcli|samba)' >> $AUTOMATION_HOME/$LOG_NAME

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== realm discover ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== realm discover ===="
realm discover 'xxxx' >> $AUTOMATION_HOME/$LOG_NAME

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== AD Join ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "Please input the xxxx user's password !!" >> $AUTOMATION_HOME/$LOG_NAME
echo "Please input the xxxx user's password !!"
realm join --client-software=sssd xxxx -U xxxx

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== PasswordAuthentication ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== PasswordAuthentication ===="
cat /etc/ssh/sshd_config | grep PasswordAuthentication >> $AUTOMATION_HOME/$LOG_NAME

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $SSSD_CONF  ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $SSSD_CONF  ===="

echo "[sssd]" > $SSSD_CONF
echo "config_file_version = 2" >> $SSSD_CONF
echo "services = nss, pam" >> $SSSD_CONF
echo "domains = xxxx" >> $SSSD_CONF
echo "" >> $SSSD_CONF
echo "[nss]" >> $SSSD_CONF
echo "filter_groups = root" >> $SSSD_CONF
echo "filter_users = root" >> $SSSD_CONF
echo "reconnection_retries = 3" >> $SSSD_CONF
echo "override_shell = /bin/bash" >> $SSSD_CONF
echo "" >> $SSSD_CONF
echo "[pam]" >> $SSSD_CONF
echo "reconnection_retries = 3" >> $SSSD_CONF
echo "" >> $SSSD_CONF
echo "[domain/xxxx]" >> $SSSD_CONF
echo "default_shell = /bin/bash" >> $SSSD_CONF
echo "ad_server = xxxx" >> $SSSD_CONF
echo "krb5_store_password_if_offline = True" >> $SSSD_CONF
echo "cache_credentials = True" >> $SSSD_CONF
echo "enumerate = false" >> $SSSD_CONF
echo "krb5_realm = xxxx" >> $SSSD_CONF
echo "realmd_tags = manages-system joined-with-adcli" >> $SSSD_CONF
echo "id_provider = ad" >> $SSSD_CONF
echo "fallback_homedir = /home/NA/%u" >> $SSSD_CONF
echo "ad_domain = xxxx" >> $SSSD_CONF
echo "use_fully_qualified_names = False" >> $SSSD_CONF
echo "ldap_id_mapping = True" >> $SSSD_CONF
echo "access_provider = simple" >> $SSSD_CONF
echo "simple_allow_groups = xxxx, $HOSTNAME_UPPER" >> $SSSD_CONF
echo "template homedir = /home/NA/%u" >> $SSSD_CONF

cat $SSSD_CONF >> $AUTOMATION_HOME/$LOG_NAME

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Restart SSSD Service ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Restart SSSD Service ===="
systemctl restart sssd.service
systemctl status sssd.service >> $AUTOMATION_HOME/$LOG_NAME

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $SYSTEM_AUTH ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $SYSTEM_AUTH ===="

echo "#%PAM-1.0" > $SYSTEM_AUTH
echo "auth        required      pam_env.so" >> $SYSTEM_AUTH
echo "auth        sufficient    pam_unix.so try_first_pass nullok" >> $SYSTEM_AUTH
echo "auth        required      pam_deny.so" >> $SYSTEM_AUTH
echo "auth        sufficient    pam_sss.so" >> $SYSTEM_AUTH
echo "" >> $SYSTEM_AUTH
echo "account     required      pam_unix.so" >> $SYSTEM_AUTH
echo "account    [default=bad success=ok user_unknown=ignore] pam_sss.so use_authtok" >> $SYSTEM_AUTH
echo "" >> $SYSTEM_AUTH
echo "password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=" >> $SYSTEM_AUTH
echo "password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow" >> $SYSTEM_AUTH
echo "password    required      pam_deny.so" >> $SYSTEM_AUTH
echo "password    sufficient    pam_sss.so" >> $SYSTEM_AUTH
echo "" >> $SYSTEM_AUTH
echo "session     optional      pam_keyinit.so revoke" >> $SYSTEM_AUTH
echo "session     required      pam_limits.so" >> $SYSTEM_AUTH
echo "-session     optional      pam_systemd.so" >> $SYSTEM_AUTH
echo "session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid" >> $SYSTEM_AUTH
echo "session     required      pam_unix.so" >> $SYSTEM_AUTH
echo "session     optional      pam_ssso.so" >> $SYSTEM_AUTH
echo "session    optional     pam_oddjob_mkhomedir.so skel=/etc/skel umask=0022" >> $SYSTEM_AUTH

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $PASSWORD_AUTH ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $PASSWORD_AUTH ===="
echo "#%PAM-1.0" > $PASSWORD_AUTH
echo "# This file is auto-generated." >> $PASSWORD_AUTH
echo "# User changes will be destroyed the nexttime authconfig is run." >> $PASSWORD_AUTH
echo "auth       required      pam_env.so" >> $PASSWORD_AUTH
echo "auth       sufficient     pam_unix.so try_first_pass nullok" >> $PASSWORD_AUTH
echo "auth       sufficient     pam_sss.so" >> $PASSWORD_AUTH
echo "auth       required      pam_deny.so" >> $PASSWORD_AUTH
echo "" >> $PASSWORD_AUTH
echo "account    required      pam_unix.so" >> $PASSWORD_AUTH
echo "account    sufficient    pam_localuser.so" >> $PASSWORD_AUTH
echo "account    [default=bad success=ok user_unknown=ignore] pam_sss.so use_authtok" >> $PASSWORD_AUTH
echo "" >> $PASSWORD_AUTH
echo "password   requisite     pam_cracklib.so try_first_pass retry=3 type=" >> $PASSWORD_AUTH
echo "password   sufficient    pam_unix.so shadow nullok try_first_pass use_authtok" >> $PASSWORD_AUTH
echo "password   required      pam_deny.so" >> $PASSWORD_AUTH
echo "" >> $PASSWORD_AUTH
echo "session    optional      pam_keyinit.so revoke" >> $PASSWORD_AUTH
echo "session    required      pam_limits.so" >> $PASSWORD_AUTH
echo "session    optional     pam_oddjob_mkhomedir.so skel=/etc/skel umask=0022" >> $PASSWORD_AUTH
echo "session    required      pam_unix.so" >> $PASSWORD_AUTH
echo "session    optional      pam_sss.so" >> $PASSWORD_AUTH

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $SUDO ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Create $SUDO ===="
echo "#%PAM-1.0" > $SUDO
echo "auth       sufficient   pam_sss.so" >> $SUDO
echo "account    sufficient   pam_sss.so" >> $SUDO
echo "password   sufficient   pam_sss.so" >> $SUDO
echo "session    optional     pam_sss.so" >> $SUDO
echo "" >> $SUDO
echo "auth       include      system-auth" >> $SUDO
echo "account    include      system-auth" >> $SUDO
echo "password   include      system-auth" >> $SUDO
echo "session    optional     pam_keyinit.so revoke" >> $SUDO
echo "session    required     pam_limits.so" >> $SUDO
echo "session    include      system-auth" >> $SUDO

echo "" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Restart SSHD Service ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "==== Restart SSHD Service ===="
systemctl restart sshd.service
systemctl status sshd.service >> $AUTOMATION_HOME/$LOG_NAME

# Install crontab
sudo yum install cronie -y
sudo systemctl enable crond.service
sudo systemctl start crond.service

echo "==== DONE ====" >> $AUTOMATION_HOME/$LOG_NAME
echo "===============" >> $AUTOMATION_HOME/$LOG_NAME

echo "DONE"
