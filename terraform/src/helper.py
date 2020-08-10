"""AWS helper class"""
import csv
import io
import os

import boto3
from boto3.dynamodb.conditions import Key
from botocore.client import Config


class DynamoDBHelper:
    @staticmethod
    def get_items(table_ame, key, value):
        """

        :param table_ame:
        :param key:
        :param value:
        :return:
        """
        items = None

        ddb = AwsHelper().get_resource("dynamodb")
        table = ddb.Table(table_ame)

        if key is not None and value is not None:
            table_filter = Key(key).eq(value)
            query_result = table.query(KeyConditionExpression=table_filter)
            if query_result and "Items" in query_result:
                items = query_result["Items"]

        return items

    @staticmethod
    def insert_item(table_name, item_data):
        """

        :param table_name:
        :param item_data:
        :return:
        """
        ddb = AwsHelper().get_resource("dynamodb")
        table = ddb.Table(table_name)

        ddb_response = table.put_item(Item=item_data)

        return ddb_response

    @staticmethod
    def delete_items(table_name, key, value, sk):
        """

        :param table_name:
        :param key:
        :param value:
        :param sk:
        """
        items = DynamoDBHelper.get_items(table_name, key, value)
        if items:
            ddb = AwsHelper().get_resource("dynamodb")
            table = ddb.Table(table_name)
            for item in items:
                print("Deleting...")
                print("{} : {}".format(key, item[key]))
                print("{} : {}".format(sk, item[sk]))
                table.delete_item(Key={key: value, sk: item[sk]})
                print("Deleted...")


class AwsHelper:
    @staticmethod
    def get_client(name, aws_region=None):
        """

        :param name:
        :param aws_region:
        :return:
        """
        config = Config(retries=dict(max_attempts=30))
        if aws_region:
            return boto3.client(name, region_name=aws_region, config=config)
        else:
            return boto3.client(name, config=config)

    @staticmethod
    def get_resource(name, aws_region=None):
        """

        :param name:
        :param aws_region:
        :return:
        """
        config = Config(retries=dict(max_attempts=30))

        if aws_region:
            return boto3.resource(name, region_name=aws_region, config=config)
        else:
            return boto3.resource(name, config=config)


class S3Helper:
    @staticmethod
    def get_s3_bucket_region(bucket_name):
        """

        :param bucket_name:
        :return:
        """
        client = boto3.client('s3')
        response = client.get_bucket_location(Bucket=bucket_name)
        aws_region = response['LocationConstraint']
        return aws_region

    @staticmethod
    def get_file_names(bucket_name, prefix, max_pages, allowed_file_types, aws_region=None):
        """

        :param bucket_name:
        :param prefix:
        :param max_pages:
        :param allowed_file_types:
        :param aws_region:
        :return:
        """
        files = []

        current_page = 1
        has_more_content = True
        continuation_token = None

        s3client = AwsHelper().get_client('s3', aws_region)

        while has_more_content and current_page <= max_pages:
            if continuation_token:
                list_objects_response = s3client.list_objects_v2(Bucket=bucket_name,
                                                                 Prefix=prefix,
                                                                 ContinuationToken=continuation_token)
            else:
                list_objects_response = s3client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)

            if list_objects_response['IsTruncated']:
                continuation_token = list_objects_response['NextContinuationToken']
            else:
                has_more_content = False

            for doc in list_objects_response['Contents']:
                doc_name = doc['Key']
                doc_ext = FileHelper.get_file_extension(doc_name)
                doc_ext_lower = doc_ext.lower()
                if doc_ext_lower in allowed_file_types:
                    files.append(doc_name)

        return files

    @staticmethod
    def write_to_s3(content, bucket_name, s3_file_name, aws_region=None):
        """

        :param content:
        :param bucket_name:
        :param s3_file_name:
        :param aws_region:
        """
        s3 = AwsHelper().get_resource('s3', aws_region)
        s3_object = s3.Object(bucket_name, s3_file_name)
        s3_object.put(Body=content)
        # ServerSideEncryption='aws:kms',
        # SSEKMSKeyId='arn:aws:kms:us-east-1:548193017565:key/e6387d1f-543d-4d02-8841-6d5a71d86410'

    @staticmethod
    def read_from_s3(bucket_name, s3_file_name, aws_region=None):
        """

        :param bucket_name:
        :param s3_file_name:
        :param aws_region:
        :return:
        """
        s3 = AwsHelper().get_resource('s3', aws_region)
        obj = s3.Object(bucket_name, s3_file_name)
        return obj.get()['Body'].read().decode('utf-8')

    @staticmethod
    def write_csv(field_names, csv_data, bucket_name, s3_file_name, aws_region=None):
        """

        :param field_names:
        :param csv_data:
        :param bucket_name:
        :param s3_file_name:
        :param aws_region:
        """
        csv_file = io.StringIO()
        # with open(fileName, 'w') as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=field_names)
        writer.writeheader()

        for item in csv_data:
            i = 0
            row = {}
            for value in item:
                row[field_names[i]] = value
                i += 1
            writer.writerow(row)
        S3Helper.write_to_s3(csv_file.getvalue(), bucket_name, s3_file_name)

    @staticmethod
    def write_csv_raw(csv_data, bucket_name, s3_file_name):
        """

        :param csv_data:
        :param bucket_name:
        :param s3_file_name:
        """
        csv_file = io.StringIO()
        # with open(fileName, 'w') as csv_file:
        writer = csv.writer(csv_file)
        for item in csv_data:
            writer.writerow(item)
        S3Helper.write_to_s3(csv_file.getvalue(), bucket_name, s3_file_name)


class FileHelper:
    @staticmethod
    def get_file_name_and_extension(file_path):
        """

        :param file_path:
        :return:
        """
        basename = os.path.basename(file_path)
        dn, dext = os.path.splitext(basename)
        return dn, dext[1:]

    @staticmethod
    def get_file_name(file_name):
        """

        :param file_name:
        :return:
        """
        basename = os.path.basename(file_name)
        dn, dext = os.path.splitext(basename)
        return dn

    @staticmethod
    def get_file_extension(file_name):
        """

        :param file_name:
        :return:
        """
        basename = os.path.basename(file_name)
        dn, dext = os.path.splitext(basename)
        return dext[1:]

    @staticmethod
    def read_file(file_name):
        """

        :param file_name:
        :return:
        """
        with open(file_name, 'r') as document:
            return document.read()

    @staticmethod
    def write_to_file(file_name, content):
        """

        :param file_name:
        :param content:
        """
        with open(file_name, 'w') as document:
            document.write(content)

    @staticmethod
    def write_to_file_with_mode(file_name, content, mode):
        """

        :param file_name:
        :param content:
        :param mode:
        """
        with open(file_name, mode) as document:
            document.write(content)

    @staticmethod
    def get_files_in_folder(path, file_types):
        """

        :param path:
        :param file_types:
        """
        for file in os.listdir(path):
            if os.path.isfile(os.path.join(path, file)):
                ext = FileHelper.get_file_extension(file)
                if ext.lower() in file_types:
                    yield file

    @staticmethod
    def get_file_names(path, allowed_local_file_types):
        """

        :param path:
        :param allowed_local_file_types:
        :return: files
        """
        files = []

        for file in FileHelper.get_files_in_folder(path, allowed_local_file_types):
            files.append(path + file)

        return files

    @staticmethod
    def write_csv(file_name, field_names, csv_data):
        """

        :param file_name:
        :param field_names:
        :param csv_data:
        """
        with open(file_name, 'w') as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=field_names)
            writer.writeheader()

            for item in csv_data:
                i = 0
                row = {}
                for value in item:
                    row[field_names[i]] = value
                    i += 1
                writer.writerow(row)

    @staticmethod
    def write_csv_raw(file_name, csv_data):
        """

        :param file_name:
        :param csv_data:
        """
        with open(file_name, 'w') as csv_file:
            writer = csv.writer(csv_file)
            for item in csv_data:
                writer.writerow(item)
