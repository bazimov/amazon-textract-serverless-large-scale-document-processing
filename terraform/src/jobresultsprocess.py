"""Lambda handler for job results process."""
import json
import logging
import time

from helper import AwsHelper
from og import OutputGenerator

logging.getLogger().setLevel(logging.INFO)


def get_job_results(api, job_id):
    """
    Get job results from textract.
    """
    pages = []

    time.sleep(5)

    client = AwsHelper().getClient('textract')
    if api == "StartDocumentTextDetection":
        response = client.get_document_text_detection(JobId=job_id)
    else:
        response = client.get_document_analysis(JobId=job_id)
    pages.append(response)
    logging.info("Result set page recieved: %s", len(pages))
    next_token = None
    if 'NextToken' in response:
        next_token = response['NextToken']
        logging.info("Next token: %s", next_token)

    while next_token:
        time.sleep(5)

        if api == "StartDocumentTextDetection":
            response = client.get_document_text_detection(
                JobId=job_id,
                NextToken=next_token,
            )
        else:
            response = client.get_document_analysis(
                JobId=job_id,
                NextToken=next_token,
            )

        pages.append(response)
        logging.info("Resultset page recieved: %s", len(pages))
        next_token = None
        if 'NextToken' in response:
            next_token = response['NextToken']
            logging.info("Next token: %s", next_token)

    return pages


def process_request(request):
    """Process results."""
    logging.debug("Request to process: %s", request)

    job_id = request['jobId']
    job_tag = request['jobTag']
    job_status = request['jobStatus']
    job_api = request['jobAPI']
    bucket_name = request['bucketName']
    object_name = request['objectName']

    if job_status != "SUCCEEDED":
        raise Exception("JobStatus is not successful: {}".format(job_status))

    pages = get_job_results(job_api, job_id)

    logging.info("Result pages recieved: %s", len(pages))

    detect_forms = False
    detect_tables = False
    if job_api == "StartDocumentAnalysis":
        detect_forms = True
        detect_tables = True

    opg = OutputGenerator(
        job_tag,
        pages,
        bucket_name,
        object_name,
        detect_forms,
        detect_tables,
    )
    opg.run()

    logging.info("DocumentId: %s", job_tag)

    output = "Processed -> Document: {}, Object: {}/{} processed.".format(
        job_tag,
        bucket_name,
        object_name,
    )

    logging.info(output)

    return {'statusCode': 200, 'body': output}


def lambda_handler(event, context):
    """Handler entrypoint."""
    logging.debug("Event: %s", event)
    logging.debug("Context: %s", context)

    body = json.loads(event['Records'][0]['body'])
    message = json.loads(body['Message'])

    logging.info("Message: %s", message)

    request = {
        "jobId": message['JobId'],
        "jobTag": message['JobId'],  # Using jobId as jobtag here.
        "jobStatus": message['Status'],
        "jobAPI": message['API'],
        "bucketName": message['DocumentLocation']['S3Bucket'],
        "objectName": message['DocumentLocation']['S3ObjectName'],
    }

    return process_request(request)
