# Lab Stack

This script can be used to create a complete stack for lab exercises
for each participant in a class. In order to use it you will need to
sign up and install the tools for CloudFormation and SES.

The lab stack is created based on a CloudFormation template which is
stored in `infra_lab.template`. The `lab_stack.sh` script however is
fairly coupled with this template at the moment.

In order to simplify the class for the participants `lab_stack.sh` will
create and upload a hosts file to each of the created machine so they
can refer to one another with friendly names like `web.part1.com`. The
email sent to the participants will also contain a section that can be
pasted into their `/etc/hosts`.

## Usage

Run the following to see the proper ways to use `lab_stack.sh`

```
./lab_stack.sh -h
```

## Setup Instructions

### Install CloudFormation command line tools either

#### with homebrew

```
brew install aws-cfn-tools
```

create a file containing your aws access keys  (ex: ~/.ec2/access.pl)

```
AWSAccessKeyId=23SDFLJ3LKJ3LKJ3F
AWSSecretKey=843LJK343ljkf4343LJKS/dsflkj43lkjs23KJ
```

add the following lines to your .bash_profile:

```
export AWS_CREDENTIAL_FILE=~/.ec2/access.pl
export AWS_CREDENTIALS_FILE=~/.ec2/access.pl
export AWS_CLOUDFORMATION_HOME=/usr/local/Cellar/aws-cfn-tools/1.0.8/jars
```

#### manually

Follow the instructions [here](https://forums.aws.amazon.com/message.jspa?messageID=227236)

### Install SES command line tools

Follow the instructions [here](http://aws.amazon.com/code/Amazon-SES/8945574369528337) You can put the
tools in `/usr/local/ses/bin` and add the following to `.bash_profile`

```
export PERL5LIB=/usr/local/ses/bin
export PATH=$PATH:/usr/local/ses/bin
export SES_FROM_EMAIL=<your email address>
```

### Verify your email address

Run the following script

```
ses-verify-email-address.pl -v <your email address>
```

Open the verification email that Amazon sends you and click on the
link. This will enable you to send emails to yourself only and is
useful for testing. You will then need to request SES production
access. THIS WILL TAKE ABOUT 24 HOURS TO PROCESS.
