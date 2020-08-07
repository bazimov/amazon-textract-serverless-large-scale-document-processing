import json
import logging
import time

from helper import AwsHelper
from og import OutputGenerator

logging.getLogger().setLevel(logging.INFO)


def getJobResults(api, jobId):
    pages = []

    time.sleep(5)

    client = AwsHelper().getClient('textract')
    if api == "StartDocumentTextDetection":
        response = client.get_document_text_detection(JobId=jobId)
    else:
        response = client.get_document_analysis(JobId=jobId)
    pages.append(response)
    print("Resultset page recieved: {}".format(len(pages)))
    nextToken = None
    if 'NextToken' in response:
        nextToken = response['NextToken']
        print("Next token: {}".format(nextToken))

    while nextToken:
        time.sleep(5)

        if api == "StartDocumentTextDetection":
            response = client.get_document_text_detection(JobId=jobId,
                                                          NextToken=nextToken)
        else:
            response = client.get_document_analysis(JobId=jobId,
                                                    NextToken=nextToken)

        pages.append(response)
        print("Resultset page recieved: {}".format(len(pages)))
        nextToken = None
        if 'NextToken' in response:
            nextToken = response['NextToken']
            print("Next token: {}".format(nextToken))

    return pages


def processRequest(request):
    output = ""

    print(request)

    jobId = request['jobId']
    jobTag = request['jobTag']
    jobStatus = request['jobStatus']
    jobAPI = request['jobAPI']
    bucketName = request['bucketName']
    objectName = request['objectName']

    if jobStatus != "SUCCEEDED":
        raise Exception("JobStatus is not successful: {}".format(jobStatus))

    pages = getJobResults(jobAPI, jobId)

    print("Result pages recieved: {}".format(len(pages)))

    detectForms = False
    detectTables = False
    if jobAPI == "StartDocumentAnalysis":
        detectForms = True
        detectTables = True

    opg = OutputGenerator(jobTag, pages, bucketName, objectName, detectForms,
                          detectTables)
    opg.run()

    print("DocumentId: {}".format(jobTag))

    output = "Processed -> Document: {}, Object: {}/{} processed.".format(
        jobTag, bucketName, objectName)

    print(output)

    return {'statusCode': 200, 'body': output}


def lambda_handler(event, context):
    print("event: {}".format(event))

    body = json.loads(event['Records'][0]['body'])
    message = json.loads(body['Message'])

    print("Message: {}".format(message))

    request = {
        "jobId": message['JobId'],
        "jobTag": message['JobId'],  # Using jobId as jobtag here.
        "jobStatus": message['Status'],
        "jobAPI": message['API'],
        "bucketName": message['DocumentLocation']['S3Bucket'],
        "objectName": message['DocumentLocation']['S3ObjectName'],
    }

    return processRequest(request)


def lambda_handler_local(event, context):
    print("event: {}".format(event))
    return processRequest(event)
