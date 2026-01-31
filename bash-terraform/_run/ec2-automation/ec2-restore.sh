#!/bin/bash

export AUTOMATION_HOME="/home/ec2-user/xxxx/ec2-restore"
export AWS_CLI_HOME="/usr/local/bin"
export LOG_NAME="ec2-restore.log"

export SNAPSHOT_ID_1="`cat $AUTOMATION_HOME/snapshot-id-1.txt`"
export SNAPSHOT_ID_2="`cat $AUTOMATION_HOME/snapshot-id-2.txt`"
export INSTANCE_ID="`cat $AUTOMATION_HOME/instance-id.txt`"

echo "=== Start "
echo "=== Start " > $AUTOMATION_HOME/$LOG_NAME

# INSTANCE_ID Null and Length Validation
if [ -z "$INSTANCE_ID" ] || [ "${#INSTANCE_ID}" -gt 30 ]; then
  echo "Invalid instance ID or null value. Exiting..."
  echo "Invalid instance ID or null value. Exiting..." >> $AUTOMATION_HOME/$LOG_NAME
  exit 1
else
        echo "INSTANCE_ID is valid"
        echo "INSTANCE_ID is valid" >> $AUTOMATION_HOME/$LOG_NAME
fi

# SNAPSHOT_ID_1 Null
if [ -z "$SNAPSHOT_ID_1" ]; then
  echo "SNAPSHOT_ID_1 is NULL. Exiting..."
  echo "SNAPSHOT_ID_1 is NULL. Exiting..." >> $AUTOMATION_HOME/$LOG_NAME
  exit 1
else
        echo "SNAPSHOT_ID_1 is valid"
        echo "SNAPSHOT_ID_1 is valid" >> $AUTOMATION_HOME/$LOG_NAME
fi

export INSTANCE_NAME="`$AWS_CLI_HOME/aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[].Instances[].Tags[?Key==\`Name\`].Value' --output text`"
export CURRENT_DATE_TIME="`date +'%Y%m%d-%H%M%S'`"
export AMI_NAME="$INSTANCE_NAME-$CURRENT_DATE_TIME"

# INSTANCE_NAME Null and Length Validation
if [ -z "$INSTANCE_NAME" ] || [ "${#INSTANCE_NAME}" -gt 200 ]; then
  echo "Invalid INSTANCE_NAME. Exiting..."
  exit 1
else
        echo "INSTANCE_NAME is valid"
        echo "INSTANCE_NAME is valid" >> $AUTOMATION_HOME/$LOG_NAME
fi

echo "=== Start " > $AUTOMATION_HOME/$LOG_NAME
echo "INSTANCE_NAME: $INSTANCE_NAME"
echo "INSTANCE_NAME: $INSTANCE_NAME" >> $AUTOMATION_HOME/$LOG_NAME
echo "SNAPSHOT_ID_1 : $SNAPSHOT_ID_1"
echo "SNAPSHOT_ID_1 : $SNAPSHOT_ID_1" >> $AUTOMATION_HOME/$LOG_NAME
echo "SNAPSHOT_ID_2 : $SNAPSHOT_ID_2"
echo "SNAPSHOT_ID_2 : $SNAPSHOT_ID_2" >> $AUTOMATION_HOME/$LOG_NAME
echo "INSTANCE_ID : $INSTANCE_ID"
echo "INSTANCE_ID : $INSTANCE_ID" >> $AUTOMATION_HOME/$LOG_NAME

# Get EBS Device Name
export BLOCK_DEVICE_1="`$AWS_CLI_HOME/aws ec2 describe-instance-attribute --instance-id $INSTANCE_ID \
--attribute blockDeviceMapping --query "BlockDeviceMappings" \
--output json | grep DeviceName | awk -F : '{ print $2 }' | tr -d ' ' | tr -d '"' | tr -d ',' | sed -n 1p`"
echo "BLOCK_DEVICE_1 : $BLOCK_DEVICE_1" 
echo "BLOCK_DEVICE_1 : $BLOCK_DEVICE_1" >> $AUTOMATION_HOME/$LOG_NAME

export BLOCK_DEVICE_2="`$AWS_CLI_HOME/aws ec2 describe-instance-attribute --instance-id $INSTANCE_ID \
--attribute blockDeviceMapping --query "BlockDeviceMappings" \
--output json | grep DeviceName | awk -F : '{ print $2 }' | tr -d ' ' | tr -d '"' | tr -d ',' | sed -n 2p`"
echo "BLOCK_DEVICE_2 : $BLOCK_DEVICE_2" 
echo "BLOCK_DEVICE_2 : $BLOCK_DEVICE_2" >> $AUTOMATION_HOME/$LOG_NAME

# Get Architecture Info
export INSTANCE_INFO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID")
export ARCHITECTURE_TYPE=$(echo "$INSTANCE_INFO" | jq -r '.Reservations[0].Instances[0].Architecture')
echo "ARCHITECTURE_TYPE : $ARCHITECTURE_TYPE"
echo "ARCHITECTURE_TYPE : $ARCHITECTURE_TYPE" >> $AUTOMATION_HOME/$LOG_NAME

# AMI 이미지 생성
echo "Creating AMI from snapshots..."
echo "Creating AMI from snapshots..." >> $AUTOMATION_HOME/$LOG_NAME

# SNAPSHOT_ID_2 Null
if [ -z "$SNAPSHOT_ID_2" ]; then
	# 1 EBS Volume
    $AWS_CLI_HOME/aws ec2 register-image --name $AMI_NAME --root-device-name "$BLOCK_DEVICE_1" \
    --block-device-mappings '[{"DeviceName":"'"$BLOCK_DEVICE_1"'","Ebs":{"SnapshotId":"'"$SNAPSHOT_ID_1"'","VolumeType":"gp3"}}]' \
    --architecture $ARCHITECTURE_TYPE | grep ImageId | awk -F ':' '{ print $2 }' | tr -d '"' | tr -d ' ' > $AUTOMATION_HOME/new-ami-id.txt

else
	# 2 EBS Volume
    $AWS_CLI_HOME/aws ec2 register-image --name $AMI_NAME --root-device-name "$BLOCK_DEVICE_1" \
    --block-device-mappings '[
        {"DeviceName":"'"$BLOCK_DEVICE_1"'","Ebs":{"SnapshotId":"'"$SNAPSHOT_ID_1"'","VolumeType":"gp3"}},
        {"DeviceName":"'"$BLOCK_DEVICE_2"'","Ebs":{"SnapshotId":"'"$SNAPSHOT_ID_2"'","VolumeType":"gp3"}}]' \
    --architecture $ARCHITECTURE_TYPE | grep ImageId | awk -F ':' '{ print $2 }' | tr -d '"' | tr -d ' ' > $AUTOMATION_HOME/new-ami-id.txt
fi


# Get AMI Image ID
export NEW_AMI_ID="`cat $AUTOMATION_HOME/new-ami-id.txt`"


# AMI 생성이 완료될 때까지 대기
# 대기 시간 제한 설정 (예: 600초 또는 10분)
timeout_seconds=600

# 시작 시간 기록
start_time=$(date +%s)

# AMI 상태가 "available"이 될 때까지 대기
while true; do
    # 현재 시간 기록
    current_time=$(date +%s)

    # 대기 시간 초과 확인
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge $timeout_seconds ]; then
        echo "AMI 상태가 'available'로 변경되지 않았습니다. 대기를 종료합니다."
        break
    fi

    # AMI 상태 확인
    ami_status=$(aws ec2 describe-images --image-ids $NEW_AMI_ID --query "Images[0].State" --output text)

    if [ "$ami_status" = "available" ]; then
        echo "AMI 상태가 'available'로 변경되었습니다."
        break
    else
        echo "AMI 상태: $ami_status, 대기 중..."
    fi

    # 5초 동안 대기
    sleep 5
done

# Backup instance.tf
mv $AUTOMATION_HOME/ec2_instance/instance.tf $AUTOMATION_HOME/ec2_instance/instance-$CURRENT_DATE_TIME.tf

# Delete the existing files
echo "Delete the existing files"
echo "Delete the existing files" >> $AUTOMATION_HOME/$LOG_NAME
rm -f $AUTOMATION_HOME/*.tf
rm -f $AUTOMATION_HOME/*.tfstate*

# Create a Sample .tf file
echo resource \"aws_security_group_rule\" \"i1\" { > $AUTOMATION_HOME/sample.tf
echo } >> $AUTOMATION_HOME/sample.tf

# Terraform Initialize - 2024.5.14
# change direcotry - 2024.7.4
cd $AUTOMATION_HOME
terraform init

# Get EC2 Configs via Terraformer
echo "Get EC2 Configs via Terraformer"
echo "Get EC2 Configs via Terraformer" >> $AUTOMATION_HOME/$LOG_NAME
terraformer import aws --resources=ec2_instance --regions=ap-northeast-2 --path-pattern=$AUTOMATION_HOME/ec2_instance --filter "Name=id;Value=$INSTANCE_ID"

elastic_ip=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

if [ -n "$elastic_ip" ]
then
    echo "이전 EC2 인스턴스의 Elastic IP 주소: $elastic_ip"
    echo "이전 EC2 인스턴스의 Elastic IP 주소: $elastic_ip" >> $AUTOMATION_HOME/$LOG_NAME
else
    echo "이전 EC2 인스턴스에 할당된 Elastic IP 주소가 없습니다."
    echo "이전 EC2 인스턴스에 할당된 Elastic IP 주소가 없습니다." >> $AUTOMATION_HOME/$LOG_NAME
fi

echo $elastic_ip > $AUTOMATION_HOME/elastic_ip.txt

# Validate instanf.tf number of lines
echo "Validate instanf.tf number of lines"
echo "Validate instanf.tf number of lines" >> $AUTOMATION_HOME/$LOG_NAME
export TF_OUTPUT_VALIDATION="`wc -l $AUTOMATION_HOME/ec2_instance/instance.tf | awk -F " " '{print $1}'`"

if [ $TF_OUTPUT_VALIDATION -gt 50 ]
then
	echo "Continue" >> $AUTOMATION_HOME/$LOG_NAME
else
	echo "Line of instance.tf output was too small" >> $AUTOMATION_HOME/$LOG_NAME
	exit 1
fi

# Copy instance.tf file to previous directory
cp $AUTOMATION_HOME/ec2_instance/instance.tf $AUTOMATION_HOME/instance.tf

# Remove not necessary lines
export LINE_NUMBER="`cat -n $AUTOMATION_HOME/instance.tf | grep cpu_options | awk -F " " '{ print $1 }'`"
sed -i "${LINE_NUMBER}d" $AUTOMATION_HOME/instance.tf
sed -i "${LINE_NUMBER}d" $AUTOMATION_HOME/instance.tf
sed -i "${LINE_NUMBER}d" $AUTOMATION_HOME/instance.tf
sed -i "${LINE_NUMBER}d" $AUTOMATION_HOME/instance.tf

sed -i "/cpu_core_count/d" $AUTOMATION_HOME/instance.tf
sed -i "/cpu_threads_per_core/d" $AUTOMATION_HOME/instance.tf
sed -i "/snapshot_id/d" $AUTOMATION_HOME/instance.tf

# AMI_ID replace
export OLD_AMI_ID="`cat $AUTOMATION_HOME/instance.tf | grep ami | awk -F "=" '{ print $2 }' | tr -d ' ' | tr -d '"'`"

echo "OLD_AMI_ID : $OLD_AMI_ID"
echo "OLD_AMI_ID : $OLD_AMI_ID" >> $AUTOMATION_HOME/$LOG_NAME

echo "NEW_AMI_ID : $NEW_AMI_ID"
echo "NEW_AMI_ID : $NEW_AMI_ID" >> $AUTOMATION_HOME/$LOG_NAME

sed -i "s/$OLD_AMI_ID/$NEW_AMI_ID/g" $AUTOMATION_HOME/instance.tf

export NEW_AMI_ID_INSTANCE_TF="`cat $AUTOMATION_HOME/instance.tf | grep ami`"

echo "NEW_AMI_ID on instance.tf : $NEW_AMI_ID_INSTANCE_TF"
echo "NEW_AMI_ID on instance.tf : $NEW_AMI_ID_INSTANCE_TF" >> $AUTOMATION_HOME/$LOG_NAME

# Disable EC2 Delete Protection
echo "Disable EC2 Delete Protection"
echo "Disable EC2 Delete Protection" >> $AUTOMATION_HOME/$LOG_NAME
$AWS_CLI_HOME/aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --no-disable-api-termination &

# EC2 인스턴스 종료
$AWS_CLI_HOME/aws ec2 terminate-instances --instance-ids $INSTANCE_ID &

# 종료 요청이 완료될 때까지 대기
echo "EC2 인스턴스 종료 요청이 접수되었습니다. 종료가 완료될 때까지 대기 중..."
echo "EC2 인스턴스 종료 요청이 접수되었습니다. 종료가 완료될 때까지 대기 중..." >> $AUTOMATION_HOME/$LOG_NAME

$AWS_CLI_HOME/aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID &

echo "EC2 인스턴스가 성공적으로 종료되었습니다."
echo "EC2 인스턴스가 성공적으로 종료되었습니다." >> $AUTOMATION_HOME/$LOG_NAME

#Delete sample.tf
rm -f $AUTOMATION_HOME/sample.tf

# Run Terraform - EC2 Creation
terraform -chdir=$AUTOMATION_HOME init


#### Awaiting until Deleting IP ADDRESS is done.
# 시작 시간 저장
start_time=$(date +%s)
# 10분 후의 시간 계산
end_time=$((start_time + 600))

# 10분이 되거나 결과가 true가 될 때까지 반복
while true; do
    current_time=$(date +%s)
    if [ $current_time -ge $end_time ]; then
        echo "Timeout reached. Exiting."
        break
    fi
    
    # 결과 확인 (예시: true가 될 때까지의 로직)
    # 결과가 true라고 가정하고 코드를 작성
    result="false" # 이 부분을 실제 결과를 반환하는 로직으로 변경해야 합니다.

    if [ `$AWS_CLI_HOME/aws ec2 describe-instances --instance-ids $INSTANCE_ID \
        --query "Reservations[*].Instances[*].PrivateIpAddress" --output text | wc -l` == 0 ]; then
        echo "DRAINING is done (0 zero)"
        break
    else
        echo "Still Waiting for 10 seconds... (Max 10 mins)"
        sleep 10
    fi
done


echo "Create EC2 as terraform apply"
echo "Create EC2 as terraform apply" >> $AUTOMATION_HOME/$LOG_NAME
terraform -chdir=$AUTOMATION_HOME apply -auto-approve

NEW_INSTANCE_ID="`aws ec2 describe-instances  \
--filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending,shutting-down,stopping" \
--query "Reservations[].Instances[?State.Name != 'terminated' && State.Name != 'stopping' && State.Name != 'shutting-down'].InstanceId" \
--output text`"

echo "NEW_INSTANCE_ID : $NEW_INSTANCE_ID"
echo "NEW_INSTANCE_ID : $NEW_INSTANCE_ID" >> $AUTOMATION_HOME/$LOG_NAME
echo "NEW_INSTANCE_ID : $NEW_INSTANCE_ID" > $AUTOMATION_HOME/new-instance-id.txt


echo "Create EC2" >> $AUTOMATION_HOME/$LOG_NAME

# EC2 인스턴스 생성이 완료될 때까지 대기
echo "Waiting for EC2 instance to be running..."
echo "Waiting for EC2 instance to be running..." >> $AUTOMATION_HOME/$LOG_NAME
$AWS_CLI_HOME/aws ec2 wait instance-running --filters "Name=instance-state-name,Values=running" &


if [ $elastic_ip == "None" ];
then
    echo "이전 EC2 인스턴스에 할당된 Elastic IP 주소가 없습니다."
    echo "이전 EC2 인스턴스에 할당된 Elastic IP 주소가 없습니다." >> $AUTOMATION_HOME/$LOG_NAME
else
    echo "Attach Elastic IP Address : $elastic_ip into $NEW_INSTANCE_ID"
    echo "Attach Elastic IP Address : $elastic_ip into $NEW_INSTANCE_ID" >> $AUTOMATION_HOME/$LOG_NAME
    echo "Wait 90 seconds for EC2 Readiness"
    echo "Wait 90 seconds for EC2 Readiness" >> $AUTOMATION_HOME/$LOG_NAME
    sleep 90s
    $AWS_CLI_HOME/aws ec2 associate-address --public-ip $elastic_ip --instance-id $NEW_INSTANCE_ID &
fi

echo "==== DONE ===="
echo "==== DONE ====" >> $AUTOMATION_HOME/$LOG_NAME
