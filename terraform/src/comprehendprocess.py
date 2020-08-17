"""Lambda handler for job comprehend process."""
import json
import logging

from helper import AwsHelper, S3Helper

try:
    from urllib.parse import unquote_plus
except ImportError:
    from urllib import unquote_plus

logging.getLogger().setLevel(logging.INFO)


def lambda_handler(event, context):
    """Handler entrypoint."""
    logging.debug("Event: %s", event)
    logging.debug("Context: %s", context)
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_name = event['Records'][0]['s3']['object']['key']
    logging.info("Bucket name %s and object name: %s", bucket_name, object_name)

    comprehend = AwsHelper.get_client("comprehend")
    s3_resource = AwsHelper.get_resource("s3")
    s3_resource.Bucket(bucket_name).download_file(Key=object_name, Filename='/tmp/{}')
    text_values = []
    text_values_entity = dict()

    with open('/tmp/{}', 'rb') as document:
        text_file_str = document.read().decode(encoding='UTF-8')

    logging.info("Starting detect_key_phrases job.")
    keyphrase_response = comprehend.detect_key_phrases(Text=text_file_str, LanguageCode='en')
    key_phrase_list = keyphrase_response.get("KeyPhrases")
    for key in key_phrase_list:
        text_values.append(key.get("Text"))

    S3Helper.write_to_s3(
        content=json.dumps(text_values),
        bucket_name=bucket_name,
        s3_file_name="{}.{}".format(object_name, ".keyPhrasesComprehend.json"),
    )

    logging.info("Starting detect_entities job.")
    detect_entity = comprehend.detect_entities(Text=text_file_str, LanguageCode='en')
    entity_list = detect_entity.get("Entities")
    for key in entity_list:
        text_values_entity.update([(key.get("Type").strip('\t\n\r'), key.get("Text").strip('\t\n\r'))])

    S3Helper.write_to_s3(
        content=json.dumps(text_values_entity),
        bucket_name=bucket_name,
        s3_file_name="{}.{}".format(object_name, ".entitiesComprehend.json"),
    )
