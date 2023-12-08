data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../main.py"
  output_path = "lambda.zip"
}

resource "random_string" "random" {
  length           = 4
  special          = false
  upper            = false
  lower            = true
  override_special = "/@£$"
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.label}-${random_string.random.result}"
}

resource "aws_s3_object" "object" {
  depends_on = [
    data.archive_file.lambda,
    aws_s3_bucket.s3_bucket
  ]
  bucket = aws_s3_bucket.s3_bucket.id
  key    = "functions/main.zip"
  source = data.archive_file.lambda.output_path
  etag   = filemd5(data.archive_file.lambda.output_path)
}

resource "aws_dynamodb_table" "table" {
  name         = "Tasks"
  hash_key     = "task_id"
  range_key    = "task_name"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "task_id"
    type = "S"
  }

  attribute {
    name = "task_name"
    type = "S"
  }

  attribute {
    name = "task_owner"
    type = "S"
  }

  global_secondary_index {
    name            = "task_name-index"
    hash_key        = "task_name"
    range_key       = "task_owner"
    projection_type = "KEYS_ONLY"
  }

  tags = {
    Name = "Tasks"
  }
}

resource "aws_iam_role" "role" {
  name               = var.label
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  depends_on = [aws_dynamodb_table.table]
  name       = "policy-${var.label}"
  path       = "/"
  policy     = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"logs:CreateLogStream",
				"logs:CreateLogGroup",
				"logs:PutLogEvents"
			],
			"Resource": "arn:aws:logs:*:*:*"
		},
		{
			"Effect": "Allow",
			"Action": [
                "s3:GetObject",
                "s3:ListBucket"

			],
			"Resource": [
              "${aws_s3_bucket.s3_bucket.arn}",
              "${aws_s3_bucket.s3_bucket.arn}/*"
            ]
		},
		{
			"Effect": "Allow",
			"Action": [
                "dynamodb:*"
			],
			"Resource": [
              "${aws_dynamodb_table.table.arn}"
            ]
		}
	]
}
EOF
}

resource "aws_iam_policy_attachment" "attachment" {
  name = "attachment-${var.label}"
  roles = [
    aws_iam_role.role.name
  ]

  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_lambda_function" "lambda" {
  depends_on = [
    aws_s3_object.object,
    aws_iam_role.role
  ]
  function_name = var.label
  description   = "Function lambda related to ${var.label}"

  role             = aws_iam_role.role.arn
  handler          = "main.lambda_handler"
  filename         = "lambda.zip"
  runtime          = "python3.10"
  memory_size      = 128
  timeout          = 60
  publish          = true
  source_code_hash = data.archive_file.lambda.output_base64sha256

  tags = {
    Name = var.label
  }
}

resource "aws_lambda_function_url" "url" {
  depends_on         = [aws_lambda_function.lambda]
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
