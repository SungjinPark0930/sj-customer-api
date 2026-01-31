#!/bin/bash

export EC2_ID="i-xxxx"
export NEW_SIZE="t3a.micro"
export AUTOMATION_HOME="/home/ec2-user/xxxx"
export ACTION_NAME="xxxx"
export AWS_CLI_HOME="/usr/local/bin"
export LOG_NAME="ec2-scale.log"
export LOG_NAME_2="ec2-scale-waiting.log"
export EMAIL_GROUP="email-list.txt"

echo "" > $AUTOMATION_HOME/$LOG_NAME
export EC2_TYPE_PREVIOUS=`$AWS_CLI_HOME/aws ec2 describe-instances --instance-ids $EC2_ID --region ap-northeast-2 | grep InstanceType`

echo "============================" >> $AUTOMATION_HOME/$LOG_NAME
echo "Previous size : " $EC2_TYPE_PREVIOUS >> $AUTOMATION_HOME/$LOG_NAME

$AWS_CLI_HOME/aws ec2 stop-instances \
        --instance-ids $EC2_ID \
        --region ap-northeast-2 > /dev/null

while true; do
    # EC2 인스턴스의 상태를 가져옵니다.
    instance_state=$($AWS_CLI_HOME/aws ec2 describe-instances --instance-ids $EC2_ID --query "Reservations[*].Instances[*].State.Name" --output text)

    # 인스턴스 상태가 "stopped"인지 확인합니다.
    if [ "$instance_state" = "stopped" ]; then
        echo "Start the modification and continue scale." >> $AUTOMATION_HOME/$LOG_NAME_2
	break
    fi

    # 10초 대기 후 다시 반복합니다.
    echo "Instance is not in stopped state." >> $AUTOMATION_HOME/$LOG_NAME_2
    sleep 5s
done

$AWS_CLI_HOME/aws ec2 modify-instance-attribute \
        --instance-type $NEW_SIZE \
        --instance-id $EC2_ID \
        --region ap-northeast-2 > /dev/null

echo "============================" >> $AUTOMATION_HOME/$LOG_NAME
echo "Scale to : " $NEW_SIZE >> $AUTOMATION_HOME/$LOG_NAME

sleep 3s
$AWS_CLI_HOME/aws ec2 start-instances \
        --instance-ids $EC2_ID \
        --region ap-northeast-2 > /dev/null

sleep 10s
export EC2_TYPE_VALIDATE=`$AWS_CLI_HOME/aws ec2 describe-instances --instance-ids $EC2_ID --region ap-northeast-2 | grep InstanceType`

echo "============================" >> $AUTOMATION_HOME/$LOG_NAME
echo "New size : " $EC2_TYPE_VALIDATE >> $AUTOMATION_HOME/$LOG_NAME
echo "============================" >> $AUTOMATION_HOME/$LOG_NAME


/usr/bin/echo "Sent from `/usr/bin/hostname`" >> $AUTOMATION_HOME/$LOG_NAME
/usr/bin/date >> $AUTOMATION_HOME/$LOG_NAME

sleep 5s
mailx -v -s "$ACTION_NAME" \
        -S smtp=smtp://xxxx:25 \
        -S from="xxxx" `cat $AUTOMATION_HOME/$EMAIL_GROUP` \
        < $AUTOMATION_HOME/$LOG_NAME
