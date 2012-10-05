#!/usr/bin/env bash

readonly STACK_TEMPLATE="infra_lab.template"
readonly FROM_EMAIL="$SES_FROM_EMAIL"
readonly SUBJECT="Your TW Infrastructure Automation Lab machines are ready"
readonly DEFAULT_USERNAME="ubuntu"

if [ -z "$SES_FROM_EMAIL" ]; then
  echo "error: SES_FROM_EMAIL environment variable not defined"
  exit 1
fi

function usage {
    cat <<EOF
Usage: ./lab_stack.sh OPTIONS

Options:
    -h                       Show this message

    -c EMAIL_ADDRESS         Create a stack for this email address
    -d EMAIL_ADDRESS         Delete a stack for this email address

    -C <FILENAME>            Create stacks from a file containing a list of
                             email addresses. Specify - to use STDIN

    -D <FILENAME>            Delete stacks from a file containing a list of
                             email addresses. Specify - to use STDIN

By default lab_stack will create stacks in the us-east-1
region. To specify a different region set the value of the EC2_REGION
environment variable to your desired region.

Notification emails will be sent from $FROM_EMAIL. In order to change
this set the value of the SES_FROM_EMAIL environment variable to the
value you would like.

EOF
}

function get_stack_status {
    stack_name=$1
    cfn-describe-stacks --show-long --stack-name "$stack_name" 2>/dev/null | cut -d, -f4 || echo ""
}

function get_stack_output {
    stack_name=$1
    cfn-describe-stacks --show-long --stack-name "$stack_name" | cut -d, -f8 || echo ""
}

function get_instance_dns {
    local instance_id=$1
    if [ -z "$instance_id" ]; then
        local instance_id=`cat -`
    fi

    ec2-describe-instances $instance_id | grep 'INSTANCE' | cut -f4
}

function get_ip {
    host $1 | cut -d' ' -f4
}

function get_positional {
    echo $1 | cut -d';' -f$2
}

function extract_instance_id {
    cut -d'=' -f2
}

function create_key {
    name=$1
    ec2-create-keypair $name | sed -n '/BEGIN/,/END/ { p; }' > $name.pem
    chmod 600 $name.pem
}

function upload_hosts_file {
    local email=$1
    shift

    local key_name=$(get_key_name_from_email $email)
    local HOSTS=$@

    local script_file=$(mktemp -t infraXXXX)

    cat <<EOF > $script_file
#!/bin/sh

echo "127.0.0.1 localhost" | sudo tee /etc/hosts > /dev/null
EOF

    for host_name_pair in $HOSTS; do
        h=$(echo $host_name_pair | cut -d'|' -f 1)
        n=$(echo $host_name_pair | cut -d'|' -f 2)
        # the single and double quotes on the next line are important. do not touch
        echo 'echo `host '$h' | cut -d" " -f4`' " $n | sudo tee -a /etc/hosts > /dev/null" >> $script_file
    done

    for host_name_pair in $HOSTS; do
        h=$(echo $host_name_pair | cut -d'|' -f 1)
        n=$(echo $host_name_pair | cut -d'|' -f 2)
        scp -o StrictHostKeyChecking=no -i $key_name.pem $script_file ubuntu@${h}:create_hosts.sh
        ssh -o StrictHostKeyChecking=no -i $key_name.pem ubuntu@${h} "bash create_hosts.sh"
    done
}

function get_positional_public_dns {
    local outputs=$1
    local position=$2
    get_positional $outputs $position | extract_instance_id | get_instance_dns
}

function notify_user {
    local email=$1
    local outputs=$2
    local key_name=$(get_key_name_from_email $email)

    MANUAL_WEB_DNS=$(get_positional_public_dns     "$outputs" 1)
    MANUAL_DB_DNS=$(get_positional_public_dns      "$outputs" 2)
    MONITOR_DNS=$(get_positional_public_dns        "$outputs" 3)
    PUPPET_WEB_DNS=$(get_positional_public_dns     "$outputs" 4)
    PUPPET_DB_DNS=$(get_positional_public_dns      "$outputs" 5)
    GO_SERVER_DNS=$(get_positional_public_dns      "$outputs" 6)

    cat <<EOF > $key_name.json
{
"web.part1.com": "$MANUAL_WEB_DNS",
"db.part1.com": "$MANUAL_DB_DNS",
"monitor.part2.com": "$MONITOR_DNS",
"web.part2.com": "$PUPPET_WEB_DNS",
"db.part2.com": "$PUPPET_DB_DNS",
"go.part3.com": "$GO_SERVER_DNS"
}
EOF

    upload_hosts_file $email "$MANUAL_WEB_DNS|web.part1.com" "$MANUAL_DB_DNS|db.part1.com" "$MONITOR_DNS|monitor.part2.com" "$PUPPET_WEB_DNS|web.part2.com" "$PUPPET_DB_DNS|db.part2.com" "$GO_SERVER_DNS|go.part3.com"

    cat <<EOF | ses-send-email.pl -s "$SUBJECT" -f "$FROM_EMAIL" -b "$FROM_EMAIL" -c "$FROM_EMAIL" $email

Welcome to the ThoughtWorks Infrastructure Automation Lab. The
following virtual machines have been assigned to you for the duration
of this lab. The username for these machines is $DEFAULT_USERNAME.


Part 1 machines:

Web Node: web.part1.com
Database Node: db.part1.com


Part 2 machines:

Monitoring Node: monitor.part2.com
Web Node: web.part2.com
Database Node: db.part2.com


Part 3 machines:

Go Server: go.part3.com


In order to access these hosts you will need to put the following in your hosts file

# start TW infrastructure lab machines
$(get_ip $MANUAL_WEB_DNS) web.part1.com
$(get_ip $MANUAL_DB_DNS) db.part1.com

$(get_ip $MONITOR_DNS) monitor.part2.com

$(get_ip $PUPPET_WEB_DNS) web.part2.com
$(get_ip $PUPPET_DB_DNS) db.part2.com

$(get_ip $GO_SERVER_DNS) go.part3.com

# end TW infrastructure lab machines

In order to access these instances you will need the following SSH
private key. Paste the following (including the --- lines) into a file
on your local machine called infra_lab.pem

`cat $key_name.pem`


Then on Linux/MacOSX you will need to restrict permissions on the key:
$ chmod 600 infra_lab.pem
Then you can ssh using
$ ssh -i infra_lab.pem $DEFAULT_USERNAME@<instance_dns_name>


On Windows you will need to use Puttygen to convert this key file to a
format that Putty can understand:
1. Go to http://bit.ly/awsputty and download putty.zip which will contain all binaries including putty.exe and puttygen.exe.
2. Run puttygen.exe
3. Import the infra_lab.pem private key  (Conversions --> Import key)
4. Click 'Save private key', don't worry about a passphrase and save it as 'infra_lab.ppk'
5. Run putty.exe
6. Go to Connection --> SSH --> Auth
7. Set the 'private key file for authentication' to your 'infra_lab.ppk' file
8. Go back to Session
9. Click on 'Default Settings' and click 'Save'
Then you can ssh by specifying one of the hostnames above and clicking 'Open'
For some helpful screenshots go to https://s3.amazonaws.com/tw-devops-bucket/putty_howto.pdf
EOF
}

function get_stack_name_from_email {
    email=$1
    echo ${email//[^a-zA-Z0-9]/}
}

function get_key_name_from_email {
    get_stack_name_from_email $1
}

function delete_stack {
    email=$1
    if [ -z "$email" ]; then
        echo "ERROR: email is required" 2>&1
        return 21
    fi

    stack_name=`get_stack_name_from_email $email`
    key_name=`get_key_name_from_email $email`

    cfn-delete-stack --force --stack-name $stack_name
    ec2-delete-keypair $key_name
    rm $key_name.pem

    echo "Stack $stack_name is now being deleted."
}

function launch_stack {
    email=$1

    if [ -z "$email" ]; then
        echo "ERROR: email is required" 2>&1
        return 21
    fi

    stack_name=`get_stack_name_from_email $email`
    key_name=`get_key_name_from_email $email`

    current_status=`get_stack_status $stack_name`
    if [ -n "$current_status" ]; then
        if [[ $current_status != "CREATE_COMPLETE" ]]; then
            echo "ERROR: A stack named $stack_name currently exists with a status of $current_status"
            return 5
        else
            echo "A stack named $stack_name already exists and appears operational. Proceeding with notifications"
            return 0
        fi
    fi

    echo "Creating keypair named $key_name..."
    create_key $key_name || (echo "ERROR: Failed to create key. Most likely a duplicate key named $key_name alrady exists. Delete it and try again" && return 6)

    echo "Creating stack named $stack_name..."
    cfn-create-stack $stack_name --template-file $STACK_TEMPLATE --parameters "Email=$email;KeyName=$key_name" || (echo "ERROR: could not launch stack" && return 10)
}

function upload_to_node {
    NODE=$1
    ROLE=$2

    rsync -az -e "ssh -i $KEY" puppet/ ubuntu@$NODE:puppet/

    ssh -i $KEY ubuntu@$NODE "sed -i -e 's/<DATABASE_SERVER>/$DATABASE_SERVER/' -e 's/<WEB_1_SERVER>/$WEB_1_SERVER/' -e 's/<WEB_2_SERVER>/$WEB_2_SERVER/' -e 's/<LOAD_BALANCER_SERVER>/$LOAD_BALANCER_SERVER/' puppet/$ROLE.pp"
}

function execute_on_node {
    NODE=$1
    ROLE=$2

    ssh -i $KEY ubuntu@$NODE "(which puppet >/dev/null || sudo apt-get install -y puppet > puppet_install.log) ; sudo puppet apply --modulepath puppet/modules puppet/$ROLE.pp"

}

function provision_stack {
    email=$1

    if [ -z "$email" ]; then
        echo "ERROR: email is required" 2>&1
        return 21
    fi

    stack_name=`get_stack_name_from_email $email`
    key_name="`get_key_name_from_email $email`.pem"

    while true; do
        sleep 5
        stack_status=`get_stack_status $stack_name`
        case "$stack_status" in
            CREATE_COMPLETE)
                echo ""
                echo "Stack live. Getting IP addresses..."
                outputs=`get_stack_output $stack_name`
                echo "provisioning..."
                deploy_to_stack "$email" "$outputs" "$key_name"
                return 0
                ;;
            *)
                echo "ERROR: Stack is in unsupported status for deployment => $stack_status"
                return 1
        esac
    done
}

function wait_for_stack_status {
    local email=$1

    if [ -z "$email" ]; then
        echo "ERROR: email is required" 2>&1
        return 21
    fi

    local stack_name=`get_stack_name_from_email $email`

    while true; do
        sleep 5
        local stack_status=`get_stack_status $stack_name`
        case "$stack_status" in
            CREATE_IN_PROGRESS)
                echo -n "."
                ;;
            CREATE_FAILED)
                echo ""
                echo "ERROR: Failed to create stack"
                return 1
                ;;
            CREATE_COMPLETE)
                echo ""
                echo "Stack created. Getting IP addresses..."
                local outputs=`get_stack_output $stack_name`
                echo "Notifying $email..."
                notify_user "$email" "$outputs"
                return 0
                ;;
            ROLLBACK_IN_PROGRESS)
                echo ""
                echo "ERROR: Stack is currently being rolled back"
                return 1
                ;;
            ROLLBACK_COMPLETE)
                echo ""
                echo "ERROR: A stack with this name has been rolled back"
                return 1
                ;;
            DELETE_*)
                echo ""
                echo "ERROR: Stack is currently in one of the delete phases => $stack_status"
                return 1
                ;;
            *)
                echo "ERROR: Unknown stack status => $stack_status"
                return 1
        esac
    done
}

function create_stack {
    launch_stack $1 && wait_for_stack_status $1
}

function create_stacks {
    count=0
    declare -a emails
    while read line; do
        email=${line%% *}
        emails[$count]=$email
        count=$(expr $count + 1)
    done

    for email in "${emails[@]}"; do
        launch_stack $email
    done

    for email in "${emails[@]}"; do
        for x in {1..5}; do
            wait_for_stack_status $email && break || delete_stack $email
            echo "Stack creation failed, retrying $x / 5"
            sleep 10
        done
    done
}

function delete_stacks {
    while read line; do
        email=${line%% *}
        delete_stack $email
    done
}

while getopts "hc:d:u:p:C:D:" opt; do
    case $opt in
        h)
            usage
            exit 0
            ;;
        c)
            create_stack $OPTARG
            exit $?
            ;;
        d)
            delete_stack $OPTARG
            exit $?
            ;;
        u)
            prepare_hosts $OPTARG
            exit $?
            ;;
        p)
            provision_stack $OPTARG
            exit $?
            ;;
        C)
            if [[ $OPTARG != "-" ]]; then
                exec 3<&0
                exec 0<"$OPTARG"
            fi

            create_stacks
            exit_code=$?

            if [[ $OPTARG != "-" ]]; then
                exec 0<&3
                exec 3<&-
            fi

            exit $exit_code
            ;;
        D)
            if [[ $OPTARG != "-" ]]; then
                exec 3<&0
                exec 0<"$OPTARG"
            fi

            delete_stacks
            exit_code=$?

            if [[ $OPTARG != "-" ]]; then
                exec 0<&3
                exec 3<&-
            fi

            exit $exit_code
            ;;
        *)
            echo "ERROR: Unknown option" 1>&2
            usage
            exit 20
    esac
done

usage
exit 30
