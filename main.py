import json
import boto3
import uuid

from botocore.exceptions import ClientError

database = boto3.resource('dynamodb')
table = database.Table('Tasks')


def lambda_handler(event, context):
    """
    Lambda function handler to route HTTP requests
    Parameters:
        - event (dict): Request data from API Gateway
        - context (LambdaContext): Runtime info
    Returns: dict: HTTP response object
    ---
    Key points:
        Docstring explains handler purpose and I/O
        Get request method from event
        Route to GET or POST functions
        POST: parse task name from body
        Return function results
    """
    
    print('INFO: starting lambda execution')
    request_method = event['requestContext']['http']['method']
    if request_method == 'GET':
        print(f'INFO: starting get request!')
        return get_items()

    elif request_method == 'POST':
        print('INFO: starting post request!')
        return post_item(event['body'])


def post_item(data):
    """
    Creates a new item in DynamoDB table with a generated UUID, and task name
    Parameters: task_name (str): The name of the task
    Returns: dict: API Gateway response with status code & body message.
    ---
    Key points:
        Function docstring explains purpose
        Documents parameters and return value
        Comments detail purpose and flow
        Follows PEP 257 docstring conventions
        Handles errors and return codes
    """
    task_id = str(uuid.uuid4()).split('-')[-1]
    content = json.loads(data)
    body_content = {
        "task_id": task_id,
        "task_name": content['task_name'],
        "task_owner": content['task_owner']
    }
    try:
        print(f'INFO: create new item on task table: body: {body_content}')
        table.put_item(Item=body_content)
        return {
            "statusCode": 200,
            "body": "Data persisted successfully"
        }
    
    except ClientError as e:
        print(f"ERROR: post request failed: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "body": str(e.response['Error']['Message'])
        }


def get_items():
    """
       Retrieves all items from a DynamoDB table
       Returns: dict: API Gateway response with status code & body
    ---
    Key points:
        Function docstring explains purpose
        Documents return value
        Handles scan of DynamoDB table
        On success returns 200 status code
        Body contains items JSON dumped to string
        Handles any errors from scan
        Returns 500 server error status code
    """
    try:
        print(f'INFO: starting get items from dynamodb table')
        response = table.scan()
        data = response['Items']
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps(data)
        }
    except ClientError as e:
        print(f'ERROR: get request failed: {e}')
        print(e.response['Error']['Message'])
        return {
            "statusCode": 500
        }
