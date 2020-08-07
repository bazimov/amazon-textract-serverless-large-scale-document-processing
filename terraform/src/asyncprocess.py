import json
import logging
import os
import time

import boto3

logging.getLogger().setLevel(logging.INFO)


def start_job(bucket_name, object_name, document_id, sns_topic, sns_role,
              detect_forms, detect_tables):
    response = dict()
    logging.info(
        "Starting job with documentId: %s, bucketName: %s, objectName: %s",
        document_id, bucket_name, object_name)

    client = boto3.client('textract')
    if not detect_forms and not detect_tables:
        logging.info("Starting StartDocumentTectDetection api call.")
        response = client.start_document_text_detection(
            ClientRequestToken=document_id,
            DocumentLocation={
                'S3Object': {
                    'Bucket': bucket_name,
                    'Name': object_name
                }
            },
            NotificationChannel={
                "RoleArn": sns_role,
                "SNSTopicArn": sns_topic
            },
            JobTag=document_id)
    else:
        features = []
        if detect_tables:
            features.append("TABLES")
        if detect_forms:
            features.append("FORMS")
        logging.info(
            "Starting StartDocumentAnalysis api call with features: %s",
            features)
        try:
            response = client.start_document_analysis(
                ClientRequestToken=document_id,
                DocumentLocation={
                    'S3Object': {
                        'Bucket': bucket_name,
                        'Name': object_name
                    }
                },
                FeatureTypes=features,
                NotificationChannel={
                    "RoleArn": sns_role,
                    "SNSTopicArn": sns_topic
                },
                JobTag=document_id)
        except Exception as error:
            logging.error(error)

    return response.get("JobId")


def process_item(message, snsTopic, snsRole):

    logging.debug("Message: %s", message)

    message_body = json.loads(message['Body'])

    bucket_name = message_body['Records'][0]['s3']['bucket']['name']
    object_name = message_body['Records'][0]['s3']['object']['key']
    document_id = message_body['Records'][0]['s3']['object']['eTag']
    # features = message_body['features']
    # detect_forms = 'Forms' in features
    # detect_tables = 'Tables' in features
    detect_forms = True
    detect_tables = True

    logging.info('Bucket Name: %s', bucket_name)
    logging.info('Object Name: %s', object_name)
    logging.info('Task ID: %s', document_id)
    # print("API: {}".format(features))

    logging.info('starting Textract job...')

    job_id = start_job(bucket_name, object_name, document_id, snsTopic,
                       snsRole, detect_forms, detect_tables)

    if job_id:
        logging.info("Started Job with Id: %s", job_id)

    return job_id


def change_visibility(sqs, q_url, receipt_handle):
    try:
        sqs.change_message_visibility(QueueUrl=q_url,
                                      ReceiptHandle=receipt_handle,
                                      VisibilityTimeout=0)
    except Exception as error:
        logging.error("Failed to change visibility for %s with error: %s",
                      receipt_handle, error)


def get_messages_from_queue(sqs, q_url):
    # Receive message from SQS queue
    response = sqs.receive_message(
        QueueUrl=q_url,
        MaxNumberOfMessages=1,
        VisibilityTimeout=60  # 14400
    )

    logging.debug('SQS Response Recieved: %s', response)

    if 'Messages' in response:
        logging.debug("Message exists returning.")
        return response['Messages']
    else:
        logging.info("No messages in the queue.")
        logging.debug("No messages in the queue. because response is %s", response)
        return None


def process_items(q_url, sns_topic, sns_role):

    sqs = boto3.client('sqs')
    messages = get_messages_from_queue(sqs, q_url)
    logging.debug("Messages from the queue: %s", messages)
    jc = 0
    total_messages = 0
    hit_limit = False
    limit_exception = None

    if messages:

        total_messages = len(messages)
        logging.info("Total messages: %s", total_messages)

        for message in messages:
            receipt_handle = message['ReceiptHandle']

            try:
                if hit_limit:
                    change_visibility(sqs, q_url, receipt_handle)
                else:
                    logging.info("starting job...")
                    process_item(message, sns_topic, sns_role)
                    logging.info("started job...")
                    logging.info('Deleting item from queue...')
                    # Delete received message from queue
                    sqs.delete_message(QueueUrl=q_url,
                                       ReceiptHandle=receipt_handle)
                    logging.info('Deleted item from queue...')
                    jc += 1
            except Exception as error:
                logging.error(
                    "Error while starting job or deleting from queue: %s",
                    error)
                change_visibility(sqs, q_url, receipt_handle)
                if (error.__class__.__name__ == 'LimitExceededException'
                        or error.__class__.__name__
                        == "ProvisionedThroughputExceededException"):
                    hit_limit = True
                    limit_exception = error

        if hit_limit:
            raise limit_exception

    return total_messages, jc


def process_request(request):

    q_url = request['q_url']
    sns_topic = request['sns_topic']
    sns_role = request['sns_role']

    i = 0
    max_call = 100  # Maximum limit for textract

    total_jobs_scheduled = 0

    hit_limit = False
    provisioned_throughput_exceeded_count = 0

    while i < max_call:
        try:
            tc, jc = process_items(q_url, sns_topic, sns_role)

            total_jobs_scheduled += jc

            if tc <= 1:
                i = max_call

        except Exception as e:
            if e.__class__.__name__ == 'LimitExceededException':
                logging.error("Exception: Hit limit.")
                hit_limit = True
                i = max_call
            elif e.__class__.__name__ == "ProvisionedThroughputExceededException":
                logging.error("ProvisionedThroughputExceededException.")
                provisioned_throughput_exceeded_count += 1
                if provisioned_throughput_exceeded_count > 5:
                    i = max_call
                else:
                    logging.info("Waiting for few seconds...")
                    time.sleep(5)
                    logging.info("Waking up...")

        i += 1

    output = "Started {} jobs.".format(total_jobs_scheduled)
    if hit_limit:
        output += " Hit limit."

    logging.info("Output: %s", output)

    return {'statusCode': 200, 'body': output}


def lambda_handler(event, context):

    logging.debug("Event: %s", event)
    logging.debug("Context: %s", context)

    request = {
        "q_url": os.environ['ASYNC_QUEUE_URL'],
        "sns_topic": os.environ['SNS_TOPIC_ARN'],
        "sns_role": os.environ['SNS_ROLE_ARN']
    }

    return process_request(request)


if __name__ == '__main__':
    lambda_handler("test", "test")
