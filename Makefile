include Makefile.mk
include Makefile.user

NAME=secrets-manager-rsa-key-rotation
S3_BUCKET=$(S3_BUCKET_PREFIX)-$(AWS_REGION)

help:
	@echo 'make                 - builds a zip file to target/.'
	@echo 'make deploy          - builds a zip file and deploys it to s3.'
	@echo 'make clean           - cleanup'
	@echo 'make deploy-lambda   - deploys the rotation lambda.'
	@echo 'make delete-lambda   - deletes the rotation lambda.'

# Copy the lambda zip package to s3
deploy: target/$(NAME)-$(VERSION).zip
	aws s3 --region $(AWS_REGION) \
		cp target/$(NAME)-$(VERSION).zip \
		s3://$(S3_BUCKET)/lambdas/$(NAME)-$(VERSION).zip
	aws s3 --region $(AWS_REGION) cp \
		s3://$(S3_BUCKET)/lambdas/$(NAME)-$(VERSION).zip \
		s3://$(S3_BUCKET)/lambdas/$(NAME)-latest.zip

# build the lambda zip package using a docker container
target/$(NAME)-$(VERSION).zip: src/*.py requirements.txt
	mkdir -p target/content
	docker build --build-arg ZIPFILE=$(NAME)-$(VERSION).zip -t $(NAME)-lambda:$(VERSION) -f Dockerfile.lambda . && \
		ID=$$(docker create $(NAME)-lambda:$(VERSION) /bin/true) && \
		docker export $$ID | (cd target && tar -xvf - $(NAME)-$(VERSION).zip) && \
		docker rm -f $$ID && \
		chmod ugo+r target/$(NAME)-$(VERSION).zip

# create the virutal environment for working in
venv: requirements.txt
	virtualenv -p python3 venv  && \
	. ./venv/bin/activate && \
	pip3 --quiet install --upgrade pip && \
	pip3 --quiet install -r requirements.txt

# cleanup virtual env, zip packages, and compiled python
clean:
	rm -rf venv target src/*.pyc tests/*.pyc

# Deploy a cloud formation containing the lambda
deploy-lambda: COMMAND=$(shell if aws cloudformation get-template-summary --stack-name $(NAME) >/dev/null 2>&1; then \
			echo update; else echo create; fi)
deploy-lambda: target/$(NAME)-$(VERSION).zip deploy
	aws cloudformation $(COMMAND)-stack \
                --capabilities CAPABILITY_IAM \
                --stack-name $(NAME) \
                --template-body file://cloudformation/secrets-manager-rsa-key-rotation.yaml \
                --parameters \
                        ParameterKey=LambdaSourceBucket,ParameterValue=$(S3_BUCKET) \
                        ParameterKey=LambdaSourceKey,ParameterValue=lambdas/$(NAME)-$(VERSION).zip
	aws cloudformation wait stack-$(COMMAND)-complete  --stack-name $(NAME)

delete-lambda:
	aws cloudformation delete-stack --stack-name $(NAME)
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)


# Deploy a cloud formation containing the lambda and a secret that uses the lambda
deploy-demo: COMMAND=$(shell if aws cloudformation get-template-summary --stack-name $(NAME)-demo >/dev/null 2>&1; then \
			echo update; else echo create; fi)
deploy-demo: target/$(NAME)-$(VERSION).zip deploy
	aws cloudformation $(COMMAND)-stack \
                --capabilities CAPABILITY_IAM \
                --stack-name $(NAME)-demo \
                --template-body file://cloudformation/secrets-manager-secret-with-rotation.yaml \
                --parameters \
                        ParameterKey=LambdaSourceBucket,ParameterValue=$(S3_BUCKET) \
                        ParameterKey=LambdaSourceKey,ParameterValue=lambdas/$(NAME)-$(VERSION).zip
	aws cloudformation wait stack-$(COMMAND)-complete  --stack-name $(NAME)-demo

delete-demo:
	aws cloudformation delete-stack --stack-name $(NAME)-demo
	aws cloudformation wait stack-delete-complete  --stack-name $(NAME)-demo


# TODO
#
#test: venv
#	for n in ./cloudformation/*.yaml ; do aws cloudformation validate-template --template-body file://$$n ; done
#	. ./venv/bin/activate && \
#	pip --quiet install -r test-requirements.txt && \
#	cd src && \
#	PYTHONPATH=$(PWD)/src pytest ../tests/test*.py
#
#autopep:
#	autopep8 --experimental --in-place --max-line-length 132 src/*.py tests/*.py
