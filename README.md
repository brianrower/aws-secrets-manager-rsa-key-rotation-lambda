# aws-secrets-manager-rsa-key-rotation-lambda
A lambda for rotating an RSA key pair stored in [AWS Secrets Manager](https://aws.amazon.com/secrets-manager).

If you want to store an RSA key pair in AWS Secrets Manager and have it automatically rotated, this lambda is for you!

## Requirements:
* awscli w/ valid credentials
* docker
* make

## How to deploy into your AWS account:
1. git clone https://github.com/brianrower/aws-secrets-manager-rsa-key-rotation-lambda.git
2. cd aws-secrets-manager-rsa-key-rotation-lambda
3. export LAMBDA_PACKAGE_BUCKET=_INSERT YOUR BUCKET NAME HERE_
4. make deploy-lambda

## What will 'make deploy-lambda' do?
* Use docker to pull down a python environment and build a lambda package with the code provided in this repositories src directory
** this results in a zip file being created in the 'target' directory, this zip file is a lambda package
* Use awscli to copy the lambda package to your S3 bucket as defined in the LAMBDA_PACKAGE_BUCKET environment variable
* Use awscli to create a cloudformation stack containing an IAM role with the required secrets manager poilicy, and a lambda using the previously created lambda package

## How to configure AWS Secrets Manager
After deploying this lambda into your environment, 
you'll want to connect it with secrets in the secret manager, here's how to do that:

### Option 1: AWS Console
* When creating a new secret in the AWS console, when promted with the options 
    "Disable automatic rotation" and "Enable automatic rotation", select 
    "Enable automatic rotation".
* Select you desired rotation interval
* In the "Choose an AWS Lambda function" box, 
    find & select the lambda that was deployed (search for "secrets-manager-rsa")
* After selecting next and storing your secret, 
    it will automatically run the rotation lambda to create an RSA key pair

### Option 2: CloudFormation
* Coming Soon