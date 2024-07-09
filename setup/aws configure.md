# AWS - Install and Configure CLI


The AWS Command Line Interface (AWS CLI) is a command-line tool that allows you to interact with AWS services using commands in your terminal/command prompt.

AWS CLI enables you to run commands to provision, configure, list, delete resources in the AWS cloud. Before you run any of the aws commands(opens in a new tab), you need to follow three steps:

## Install AWS CLI

- Create an IAM user with Administrator permissions
- Configure the AWS CLI

*Step 1. Install AWS CLI v2*

Refer to the official [AWS instructions to install/update AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)(version 2) based on your underlying OS. You can verify the installation using the following command in your terminal (macOS)/cmd (Windows).

# Display the folder that contains the symlink to the aws cli tool

`which aws`
# See the current version
`aws --version`
See the sample output below. Note that the exact version of AWS CLI and Python may vary in your system.

Mac/Linux/Windows: Verify the successful installation of AWS CLI 2
Mac/Linux/Windows: Verify the successful installation of AWS CLI 2


*Step 2. Create an IAM user*
In this step, you will create an IAM user with Administrator permissions who is allowed to perform any action in your AWS account, only through CLI. After creating such an IAM user, we will use its Access key (long-term credentials)** **to configure the AWS CLI locally.

Let’s create an AWS IAM(opens in a new tab) user, and copy its Access key.

AWS Identity and Access Management (IAM) service allows you to authorize users / applications (such as AWS CLI) to access AWS resources.

The Access key is a combination of an Access Key ID and a Secret Access Key. Let's see the steps to create an IAM user, and generate its Access key.

Navigate to the IAM Dashboard(opens in a new tab), and create an IAM user.
Display of Add a new IAM user page image
Add a new IAM user

Set the user name, and click Next. DO NOT check Provide user access to the AWS Management Console - optional.
Screenshot showing how to specify user details and with recommendation to not check AWS Management Console option.
Set User name.

Set the permissions to the new user by attaching the AWS Managed AdministratorAccess policy from the list of existing policies.
Attach the *AdministratorAccess* policy from the list of pre-created policies
Attach the AdministratorAccess policy from the list of pre-created policies

Provide tags [optional], review the details of the new user, and finally create the new user.
After a user is created successfully, click on the User name.
Select the created user from the list of user names.
Select the created user.

Ignore AWS Management Console related warnings. Since you only need programmatic acces, this can be ignored. Go to Security Credentials and select Create access key.
Create Access Key for the user and ignore AWS management Console related warnings.
Create Access Key for the user.

Select Command Line Interface (CLI) and click Next.
Since we wan't to access AWS from the CLI, select Command Line Interface (CLI)
Select Command Line Interface (CLI)

Optional - Set descrption tag and click Create access key.
Optionally, set description tag for the access keys
Optional - Set description tag for the access keys

Copy the created Access key, Secret access key and store it for later use. You can also download these as a .csv file.
Copy Access Key and Secret Access Key
Copy Access Key and Secret Access Key

Note that you can generate a temporary Access key in the classroom as well, as shown in the snapshot below. But, the classroom generated access key is valid for a for a few hours only. Notice that it has a session token associated with it.

Access key shown in the classroom after clicking on the "OPEN CLOUD GATEWAY" button
Access key shown in the classroom after clicking on the "OPEN CLOUD GATEWAY" button

Step 3. Configure the AWS CLI
You will need to configure the following four items on your local machine before you can interact with any of the AWS services:

Access key - It is a combination of an Access Key ID and a Secret Access Key. Together, they are referred to as Access key. You can generate an Access key from the AWS IAM service, and specify the level of permissions (authorization) with the help of IAM Roles.
Default AWS Region - It specifies the AWS Region where you want to send your requests by default.
Default output format - It specifies how the results are formatted. It can either be a json, yaml, text, or a table.
Profile - A collection of settings is called a profile. The default profile name is default, however, you can create a new profile using the aws configure --profile new_name command.
Here are the steps to configure the AWS CLI in your terminal:

Run the command below to configure the AWS CLI using the Access Key ID and a Secret Access Key generated in the previous step. If you have closed the web console that showed the access key, you can open the downloaded access key file (.csv) to copy the keys later.
aws configure 
If you already have a profile set locally, you can use --profile <profile-name> option with any of the AWS commands above. This will resolve the conflict with the existing profiles set up locally. Next, use the following values in the prompt that would appear:

Prompt	Value
AWS Access Key ID	[Copy from the classroom]
AWS Secret Access Key	[Copy from the classroom]
Default region name	us-east-2
(or your choice)
Default output format	json
* **Important** - ```bash # If you are using the Access key of an Admin IAM user, you should reset the `aws_session_token` aws configure set aws_session_token "" # If you are using the Udacity generated Access key, you should set the `aws_session_token` aws configure set aws_session_token "XXXXXXXX" ``` where, `"XXXXXXXX"` is the session token copied from the classroom after clicking on the "OPEN CLOUD GATEWAY" button.
The commands above will store the access key in a default file ~/.aws/credentials and store the profile in the ~/.aws/config file. Upon prompt, paste the copied access key (access key id and secret access key). Enter the default region as us-east-2 and output format as json. You can verify the saved config using:
# View the current configuration
aws configure list 
# View all existing profile names
aws configure list-profiles
# In case, you want to change the region in a given profile
# aws configure set <parameter> <value>  --profile <profile-name>
aws configure set region us-east-2  
Mac/Linux: A successful configuration
Mac/Linux: A successful configuration

Let the system know that your sensitive information is residing in the .aws folder
export AWS_CONFIG_FILE=~/.aws/config
export AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials
Windows users with GitBash only
You will have to set the environment variables. Run the following commands in your GitBash terminal:
setx AWS_ACCESS_KEY_ID AKIAIOSFODNN7EXAMPLE
setx AWS_SECRET_ACCESS_KEY wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
setx AWS_DEFAULT_REGION us-west-2
Replace the access key ID and secret, as applicable to you. Windows users using WSL do not need this step, they will follow all steps as if they are Linux users.

Windows: Successful configuration using the GitBash terminal
Windows: Successful configuration using the GitBash terminal

Step 4. Run your first AWS CLI command
Check the successful configuration of the AWS CLI, by running either of the following AWS command:
# If you've just one profile set locally
aws iam list-users
# If you've multiple profiles set locally
aws iam list-users --profile <profile-name>
The output will display the details of the recently created user:

{
"Users": [
    {
        "Path": "/",
        "UserName": "Admin",
        "UserId": "AIDNWUBRJIBR98311",
        "Arn": "arn:aws:iam::388752792305:user/Admin",
        "CreateDate": "2021-01-28T13:44:15+00:00"
    }
]
}

$ aws iam list-users --profile ahamadmin

Troubleshoot
If you are facing issues while following the commands above, refer to the detailed instructions here -

Configuration basics(opens in a new tab)
Configuration and credential file settings(opens in a new tab)
Environment variables to configure the AWS CLI(opens in a new tab)
Updating the specific variable in the configuration
In the future, you can set a single value, by using the command, such as:

# Syntax
# aws configure set <varname> <value> [--profile profile-name]
 aws configure set default.region us-east-2
It will update only the region variable in the existing default profile.

https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/ 

kubectl configuration is located at ~/.kube/config

kubectl config current-context