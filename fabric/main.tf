# Configure the AWS Provider
provider "aws" {
  access_key = "AKIAJPBBM67CRNIDVYTQ"
  secret_key = "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"
  region     = "us-west-2"
}



resource "aws_s3_bucket" "pn-reporting-dev-streaming-processed-gps-data12" {
    bucket = "pn-reporting-dev-streaming-processed-gps-data12"
    acl    = "private"
}

resource "aws_s3_bucket" "pn-reporting-dev-streaming-s3-gps-datalake12" {
    bucket = "pn-reporting-dev-streaming-s3-gps-datalake12"
    acl    = "private"
}



resource "aws_subnet" "subnet-b6ea9ad1" {
    vpc_id                  = "${aws_vpc.PN-Reporting-Dev-Streaming-VPC.id}"
    cidr_block              = "10.0.0.0/16"
    availability_zone       = "us-west-2b"
    map_public_ip_on_launch = true
	depends_on = ["aws_vpc.PN-Reporting-Dev-Streaming-VPC"]
    tags {
        "Name" = "PN-Reporting-Dev-Streaming-Subnet-West-2b"
    }
}
resource "aws_vpc" "PN-Reporting-Dev-Streaming-VPC" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
    instance_tenancy     = "default"

    tags {
        "Name" = "PN-Reporting-Dev-Streaming-VPC"
    }
}


resource "aws_security_group" "PN-Reporting-Dev-Streaming-EC2-SG-vpc-378bae50" {
    name        = "PN-Reporting-Dev-Streaming-EC2-SG"
    description = "PN-Reporting-Dev-Streaming-EC2-SG created for new EC2 instance"
    vpc_id      = "${aws_vpc.PN-Reporting-Dev-Streaming-VPC.id}"
	depends_on = [ "aws_vpc.PN-Reporting-Dev-Streaming-VPC"]

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }


    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

}




resource "aws_instance" "PN-Reporting-Dev-EC2-KinesisAgent" {
	depends_on= ["aws_security_group.PN-Reporting-Dev-Streaming-EC2-SG-vpc-378bae50",
                        "aws_subnet.subnet-b6ea9ad1"]
    ami                         = "ami-8ca83fec"
    availability_zone           = "us-west-2b"
    ebs_optimized               = false
    instance_type               = "t2.micro"
	monitoring                  = false  
      subnet_id                   = "${aws_subnet.subnet-b6ea9ad1.id}"
    vpc_security_group_ids      = ["${aws_security_group.PN-Reporting-Dev-Streaming-EC2-SG-vpc-378bae50.id}"]
    associate_public_ip_address = true
    private_ip                  = "10.0.183.231"
    source_dest_check           = true

    root_block_device {
        volume_type           = "gp2"
        volume_size           = 8
        delete_on_termination = true
    }

    tags {
        "Name" = "PN-Reporting-Dev-Streaming-EC2-KinesisAgent"
    }
}




resource "aws_iam_role" "PN-Reporting-Dev-Streaming-Role-firehose-delivery" {
    name               = "PN-Reporting-Dev-Streaming-Role-firehose-delivery"

    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
      
    }
  ]
}
POLICY
}

resource "aws_iam_role" "PN-Reporting-Dev-Streaming-Role-LambdaExecution" {
    name               = "PN-Reporting-Dev-Streaming-Role-LambdaExecution"
    path               = "/"
    assume_role_policy = <<POLICY
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
POLICY
}


resource "aws_dynamodb_table" "CopyToDB" {
  name           = "CopyToDB"
  read_capacity  = 3
  write_capacity = 3
  hash_key = "Reprocessing"
  range_key      = "ExecutionCopytoDBID"

  attribute {
    name = "Reprocessing"
    type = "N"
  }

  attribute {
    name = "ExecutionCopytoDBID"
    type = "N"
  }

  

  tags {
    Name        = "copyTodb"
    Environment = "development"
  }
}

resource "aws_dynamodb_table" "EventProcessExecution" {
  name           = "EventProcessExecution"
  read_capacity  = 3
  write_capacity = 3
  hash_key       = "ExecutionProcessID"
  range_key      = "RecordID"

  attribute {
    name = "ExecutionProcessID"
    type = "S"
  }

  attribute {
    name = "RecordID"
    type = "S"
  }

  

  tags {
    Name        = "EventProcessExecution"
    Environment = "development"
  }
}

resource "aws_dynamodb_table" "Events" {
  name           = "Events"
  read_capacity  = 3
  write_capacity = 3
  hash_key       = "RecordID"
  range_key      = "Status"

  attribute {
    name = "RecordID"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  

  tags {
    Name        = "Events"
    Environment = "development"
  }
}
resource "aws_dynamodb_table" "StreamSetup" {
  name           = "StreamSetup"
  read_capacity  = 3
  write_capacity = 3
  hash_key       = "StreamName"


  attribute {
    name = "StreamName"
    type = "S"
  }
 
  tags {
    Name        = "StreamSetup"
    Environment = "development"
  }
}


resource "aws_lambda_function" "PN-Reporting-Dev-Streaming-Lambda-CopyToDB" {
  filename	= "CopyToDB.zip"
   depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution"]
  function_name    = "PN-Reporting-Dev-Streaming-Lambda-CopyToDB"
  role             = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution.arn}"
  handler          = "index.handler"
  runtime          = "nodejs4.3"
  timeout = "120"
  environment {
    variables = {
    IntitalExecutionID= "1",
	exID= "1",
	failStatus="Failed",
    progStatus="Progress",
    reExId="100",
    reProcessingChildValue= "1",
    reProcessingParentValue= "0",
    region="us-west-2",
    replaceKeyword= "replace",
    retryFinalValue= "2",
    retryIntialValue= "0",
    snowflakeAccount= "vusion",
    snowflakeDatabase="PNETDW",
    snowflakePassword="pNetETLDeveloper",
    snowflakeSchema="etl",
    snowflakeUserName= "pNetETLDeveloper",
    snowflakeWarehouse="PNETDWDEV",
    successStatus="Completed",
    tableNameCopy= "CopyToDB",
    tableNameStreamDetails="StreamSetup",
    zeroExecutionID="0"
    }
  }
  
}



resource "aws_lambda_function" "PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB" {
  filename = "SnowFlakeReProcess.zip"
  depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution"]
  function_name    = "PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB"
  role             = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution.arn}"
  handler          = "index.handler"
  runtime          = "nodejs4.3"
  timeout = "120"
  environment {
    variables = {
    IntitalExecutionID= "1",
	exID= "1",
	failStatus="Failed",
    progStatus="Progress",
    reExId="100",
    reProcessingChildValue= "1",
    reProcessingParentValue= "0",
    region="us-west-2",
    replaceKeyword= "replace",
    retryFinalValue= "2",
    retryIntialValue= "0",
    snowflakeAccount= "vusion",
    snowflakeDatabase="PNETDW",
    snowflakePassword="pNetETLDeveloper",
    snowflakeSchema="etl",
    snowflakeUserName= "pNetETLDeveloper",
    snowflakeWarehouse="PNETDWDEV",
    successStatus="Completed",
    tableNameCopy= "CopyToDB",
    tableNameStreamDetails="StreamSetup",
    zeroExecutionID="0"
    }
  }
  
}




resource "aws_cloudwatch_event_rule" "PN-Reporting-Dev-Streaming-every-five-minutes" {
depends_on = ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB"]
    name = "PN-Reporting-Dev-Streaming-every-five-minutes"
    description = "Fires every five minutes"
    schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB-every-five-minutes" {
depends_on = ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB","aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-every-five-minutes"]
    rule = "${aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-every-five-minutes.name}"
    target_id = "PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB"
    arn = "${aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB.arn}"
}



resource "aws_lambda_permission" "PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB-allow-cloudwatch-to-call" {
depends_on = ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB","aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-every-five-minutes"]
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-Reprocess-CopyToDB.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-every-five-minutes.arn}"
}


resource "aws_lambda_function" "PN-Reporting-Dev-Streaming-Lambda-ProcessData" {
   filename = "ProcessData.zip"
   depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution"]
  function_name    = "PN-Reporting-Dev-Streaming-Lambda-ProcessData"
  role             = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution.arn}"
  handler          = "index.handler"
  runtime          = "nodejs4.3"  
}

resource "aws_lambda_function" "PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data" {
     filename = "ReProcessData.zip"
  function_name    = "PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data"
  depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution"]
  role             = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution.arn}"
  handler          = "index.handler"
  runtime          = "nodejs4.3"
  
}



resource "aws_cloudwatch_event_rule" "PN-Reporting-Dev-Streaming-Rule-Reprocess-Data-GPS" {
depends_on = ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data"]
    name = "PN-Reporting-Dev-Streaming-Rule-Reprocess-Data-GPS"
    description = "Fires every five minutes for reprocess data gps lambda function"
    schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "PN-Reporting-Dev-Streaming-Lambda-Reprocess-Data-every-five-minutes" {
depends_on = ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data","aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-Rule-Reprocess-Data-GPS"]
    rule = "${aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-Rule-Reprocess-Data-GPS.name}"
    target_id = "PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data"
    arn = "${aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data.arn}"
}

resource "aws_lambda_permission" "PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data-allow-cloudwatch-to-call" {
depends_on = ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data","aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-Rule-Reprocess-Data-GPS"]
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-ReProcess-Data.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.PN-Reporting-Dev-Streaming-Rule-Reprocess-Data-GPS.arn}"
}



resource "aws_lambda_function" "PN-Reporting-Streaming-GPS-DataLake" {
     filename = "DataLakeProcess.zip"
	 depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution"]
  function_name    = "PN-Reporting-Streaming-GPS-DataLake"
  role             = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution.arn}"
  handler          = "index.handler"
  runtime          = "nodejs4.3"
  
}

resource "aws_lambda_permission" "PN-Reporting-Dev-Streaming-allow_bucket" {
depends_on= ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-CopyToDB",
                        "aws_s3_bucket.pn-reporting-dev-streaming-processed-gps-data12"]
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-CopyToDB.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.pn-reporting-dev-streaming-processed-gps-data12.arn}"
}

resource "aws_s3_bucket_notification" "PN-Reporting-Dev-Streaming-bucket_notification" {
  bucket = "${aws_s3_bucket.pn-reporting-dev-streaming-processed-gps-data12.id}"
 depends_on= ["aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-CopyToDB",
                        "aws_s3_bucket.pn-reporting-dev-streaming-processed-gps-data12"]
  lambda_function {
    lambda_function_arn = "${aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-CopyToDB.arn}"
    events              = ["s3:ObjectCreated:Put"]
 
  }
}

resource "aws_kinesis_firehose_delivery_stream" "PN-Reporting-Dev-Streaming-Firehose-GPS-DataLake" {
  name        = "PN-Reporting-Dev-Streaming-Firehose-GPS-DataLake"
  destination = "s3"
depends_on = ["aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery",
                        "aws_lambda_function.PN-Reporting-Streaming-GPS-DataLake",
                        "aws_s3_bucket.pn-reporting-dev-streaming-s3-gps-datalake12"]
  s3_configuration {
    role_arn   = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery.arn}"
    bucket_arn = "${aws_s3_bucket.pn-reporting-dev-streaming-s3-gps-datalake12.arn}"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "PN-Reporting-Dev-Streaming-Firehose" {
  name        = "PN-Reporting-Dev-Streaming-Firehose"
  destination = "s3"
depends_on = ["aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery",                        "aws_lambda_function.PN-Reporting-Dev-Streaming-Lambda-ProcessData",                        "aws_s3_bucket.pn-reporting-dev-streaming-processed-gps-data12"]
  s3_configuration {
    role_arn   = "${aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery.arn}"
    bucket_arn = "${aws_s3_bucket.pn-reporting-dev-streaming-processed-gps-data12.arn}"
  }
}
resource "aws_iam_policy_attachment" "AWSLambdaFullAccess-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "AWSLambdaFullAccess-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}

resource "aws_iam_policy_attachment" "AmazonElastiCacheFullAccess-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution","aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "AmazonElastiCacheFullAccess-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-LambdaExecution","PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}

resource "aws_iam_policy_attachment" "AmazonS3FullAccess-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution","aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "AmazonS3FullAccess-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-LambdaExecution","PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}

resource "aws_iam_policy_attachment" "CloudWatchFullAccess-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution","aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "CloudWatchFullAccess-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-LambdaExecution","PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}

resource "aws_iam_policy_attachment" "AmazonDynamoDBFullAccess-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution","aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "AmazonDynamoDBFullAccess-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-LambdaExecution","PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}


resource "aws_iam_policy_attachment" "AmazonKinesisFirehoseFullAccess-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution","aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "AmazonKinesisFirehoseFullAccess-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFirehoseFullAccess"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-LambdaExecution","PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}

resource "aws_iam_policy_attachment" "AWSLambdaVPCAccessExecutionRole-policy-attachment" {
depends_on=["aws_iam_role.PN-Reporting-Dev-Streaming-Role-LambdaExecution","aws_iam_role.PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
    name       = "AWSLambdaVPCAccessExecutionRole-policy-attachment"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    groups     = []
    users      = []
    roles      = ["PN-Reporting-Dev-Streaming-Role-LambdaExecution","PN-Reporting-Dev-Streaming-Role-firehose-delivery"]
}
