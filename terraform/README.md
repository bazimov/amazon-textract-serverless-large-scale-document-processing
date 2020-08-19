## Architecture PoC

Architecture below shows the core components. 

![](arch.png)

TODO: There are multiple todo items here, I will be working on them next. Just wanted to bring up quick MVP to test out.

## Install
(These instructions assume you run MAC OS)
How to install the infrastructure via terraform

### Initialize
Assumes you have default credentials in default location.
If you store credentials in custom location change the path below.
If you have custom profile add extra argument `-e AWS_PROFILE=custom`.
```shell script
cd terraform/
docker run --rm -it \
  -v $PWD:/opt \
  -w /opt \
  -v $HOME/.aws/credentials:/root/.aws/credentials \
  hashicorp/terraform:0.13.0 init
```
### Plan
```shell script
docker run --rm -it \
  -v $PWD:/opt \
  -w /opt \
  -v $HOME/.aws/credentials:/root/.aws/credentials \
  hashicorp/terraform:0.13.0 plan
```
### Apply
```shell script
docker run --rm -it \
  -v $PWD:/opt \
  -w /opt \
  -v $HOME/.aws/credentials:/root/.aws/credentials \
  hashicorp/terraform:0.13.0 apply
```

### Cleanup / Destroy
```shell script
docker run --rm -it \
  -v $PWD:/opt \
  -w /opt \
  -v $HOME/.aws/credentials:/root/.aws/credentials \
  hashicorp/terraform:0.13.0 destroy
```

### How to use/test this infrastructure?
1. Code creates one bucket with prefix `s3://textract-source-bucket`. You can upload the sample_f1040.pdf file or any
PDF file you have to the bucket. (Must provide encryption key)
    ```shell script
    aws s3 cp sample_f1040.pdf s3://<bucket_name_here/> --sse <s3_key_arn>
    ```
2. PDF file will be sent to SQS queue and Lambda will pick it up to process with the Textract. Results will be sent back to
s3 bucket with prefix of <file_name-analysis>. There will be raw response.json response and per page filtered responses 
such as csv, txt, json files.
4. 1st text page of the document will kick off Comprehend job to further analyze the text document.
Results will be delivered as a file with extensions that include "Comprehend" phrase in them.
5. You can see the files within the UI or with listing the bucket.
    ```shell script
    aws s3 ls s3://<bucket_name>
    ```
