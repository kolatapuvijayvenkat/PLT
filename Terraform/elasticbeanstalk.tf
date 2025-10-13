###########################################
# ELASTIC BEANSTALK DEPLOYMENT WITH S3
###########################################

# -----------------------------
# 1️⃣ Elastic Beanstalk Application
# -----------------------------
resource "aws_elastic_beanstalk_application" "app" {
  name        = "nodejs-app"
  description = "Node.js Elastic Beanstalk Application"
}

# -----------------------------
# 2️⃣ IAM ROLES
# -----------------------------

# --- Service Role ---
resource "aws_iam_role" "eb_service_role" {
  name = "aws-elasticbeanstalk-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticbeanstalk.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eb_service_role_basic" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_role_policy_attachment" "eb_service_role_enhanced" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

# --- EC2 Instance Role ---
resource "aws_iam_role" "eb_instance_role" {
  name = "aws-elasticbeanstalk-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eb_instance_web" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_instance_worker" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_instance_multicontainer" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "aws-elasticbeanstalk-ec2-profile"
  role = aws_iam_role.eb_instance_role.name
}

# -----------------------------
# 3️⃣ S3 Bucket & Upload app.zip
# -----------------------------
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "eb_app_bucket" {
  bucket        = "eb-app-bucket-${random_id.bucket_id.hex}"
  force_destroy = true

  tags = {
    Name = "EB App Bucket"
  }
}

# Block all public access (modern best practice)
resource "aws_s3_bucket_public_access_block" "eb_app_bucket_block" {
  bucket                  = aws_s3_bucket.eb_app_bucket.id
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

# Upload app.zip (your application bundle)
resource "aws_s3_object" "app_zip" {
  bucket = aws_s3_bucket.eb_app_bucket.id
  key    = "app.zip"
  source = "${path.module}/app.zip"

  etag = filemd5("${path.module}/app.zip")

  depends_on = [aws_s3_bucket_public_access_block.eb_app_bucket_block]
}

# -----------------------------
# 4️⃣ Application Version
# -----------------------------
resource "aws_elastic_beanstalk_application_version" "app_version" {
  application = aws_elastic_beanstalk_application.app.name
  name        = "v-${timestamp()}"
  description = "Deployed via Terraform"

  bucket = aws_s3_bucket.eb_app_bucket.bucket
  key    = aws_s3_object.app_zip.key
}

# -----------------------------
# 5️⃣ Elastic Beanstalk Environment
# -----------------------------
resource "aws_elastic_beanstalk_environment" "env" {
  name                = "nodejs-env"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.6.6 running Node.js 22"
  version_label       = aws_elastic_beanstalk_application_version.app_version.name

  # --- Network ---
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${aws_subnet.public_1.id},${aws_subnet.public_2.id}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = "${aws_subnet.public_1.id},${aws_subnet.public_2.id}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_sg.id
  }

  # --- Compute ---
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service_role.name
  }

  # --- Scaling ---
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  tags = {
    Name = "nodejs-eb-env"
  }

  depends_on = [
    aws_iam_instance_profile.eb_instance_profile,
    aws_iam_role_policy_attachment.eb_instance_web,
    aws_vpc.main,
    aws_subnet.public_1,
    aws_subnet.public_2,
    aws_s3_object.app_zip
  ]
}
