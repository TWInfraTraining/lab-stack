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

In order to run the lab-stack, you will need to follow the instructions
[here](https://github.com/ThoughtWorksInc/InfraTraining) to setup AWS and
your machine.