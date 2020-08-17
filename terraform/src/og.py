import json

from helper import S3Helper
from trp import Document


class OutputGenerator:
    """
    Output generator
    """
    def __init__(self, document_id, response, bucket_name, object_name, forms, tables, ddb=None):
        self.document_id = document_id
        self.response = response
        self.bucket_name = bucket_name
        self.object_name = object_name
        self.forms = forms
        self.tables = tables
        self.ddb = ddb
        self.output_path = "{}-analysis/{}/".format(object_name, document_id)

        self.document = Document(self.response)

    def _output_text(self, page, page_number):
        text = page.text
        opath = "{}page-{}-text.txt".format(self.output_path, page_number)
        S3Helper.write_to_s3(text, self.bucket_name, opath)
        # self.saveItem(self.documentId, "page-{}-Text".format(p), opath)

        text_in_reading_order = page.getTextInReadingOrder()
        opath = "{}page-{}-text-inreadingorder.txt".format(self.output_path, page_number)
        S3Helper.write_to_s3(text_in_reading_order, self.bucket_name, opath)
        # self.saveItem(self.documentId, "page-{}-TextInReadingOrder".format(p), opath)

    def _output_form(self, page, page_number):
        csv_data = []
        for field in page.form.fields:
            csv_item = []
            if field.key:
                csv_item.append(field.key.text)
            else:
                csv_item.append("")
            if field.value:
                csv_item.append(field.value.text)
            else:
                csv_item.append("")
            csv_data.append(csv_item)
        csv_field_names = ['Key', 'Value']
        opath = "{}page-{}-forms.csv".format(self.output_path, page_number)
        S3Helper.write_csv(csv_field_names, csv_data, self.bucket_name, opath)
        # self.saveItem(self.documentId, "page-{}-Forms".format(p), opath)

    def _output_table(self, page, page_number):

        csv_data = []
        for table in page.tables:
            csv_row = ["Table"]
            csv_data.append(csv_row)
            for row in table.rows:
                csv_row = []
                for cell in row.cells:
                    csv_row.append(cell.text)
                csv_data.append(csv_row)
            csv_data.append([])
            csv_data.append([])

        opath = "{}page-{}-tables.csv".format(self.output_path, page_number)
        S3Helper.write_csv_raw(csv_data, self.bucket_name, opath)
        # self.saveItem(self.documentId, "page-{}-Tables".format(p), opath)

    def run(self):
        """

        :return:
        """
        if not self.document.pages:
            return

        output_path = "{}response.json".format(self.output_path)
        S3Helper.write_to_s3(json.dumps(self.response), self.bucket_name, output_path)
        # self.saveItem(self.documentId, 'Response', opath)

        print("Total Pages in Document: {}".format(len(self.document.pages)))

        doc_text = ""

        page_number = 1
        for page in self.document.pages:

            output_path = "{}page-{}-response.json".format(self.output_path, page_number)
            S3Helper.write_to_s3(json.dumps(page.blocks), self.bucket_name, output_path)
            # self.saveItem(self.documentId, "page-{}-Response".format(p), opath)

            self._output_text(page, page_number)

            doc_text = doc_text + page.text + "\n"

            if self.forms:
                self._output_form(page, page_number)

            if self.tables:
                self._output_table(page, page_number)

            page_number += 1
