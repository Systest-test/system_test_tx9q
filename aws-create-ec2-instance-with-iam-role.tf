data "aws_resourcegroupstaggingapi_resources" "ifExist" {
  resource_type_filters = ["ec2:instance"]
  tag_filter {
    key    = "Name"
    values = ["dnd-systest-ec2-iam-role"]
  }
}

output "arns" {
  value = length(data.aws_resourcegroupstaggingapi_resources.ifExist.resource_tag_mapping_list.*.resource_arn) == 0 ? "1" : "0"
}

resource "aws_iam_role" "aws_iam_role" {
  count = length(data.aws_resourcegroupstaggingapi_resources.ifExist.resource_tag_mapping_list.*.resource_arn) == 0 ? "1" : "0"
  name = "ec2_aws_iam_role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "aws_iam_role_policy" {
  count = length(data.aws_resourcegroupstaggingapi_resources.ifExist.resource_tag_mapping_list.*.resource_arn) == 0 ? "1" : "0"
  name   = "ec2_aws_iam_role_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
                "iam:*",
                "organizations:DescribeAccount",
                "organizations:DescribeOrganization",
                "organizations:DescribeOrganizationalUnit",
                "organizations:DescribePolicy",
                "organizations:ListChildren",
                "organizations:ListParents",
                "organizations:ListPoliciesForTarget",
                "organizations:ListRoots",
                "organizations:ListPolicies",
                "organizations:ListTargetsForPolicy"
            ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })

  role = aws_iam_role.aws_iam_role[count.index].id
}

resource "aws_iam_instance_profile" "test_profile" {
  count = length(data.aws_resourcegroupstaggingapi_resources.ifExist.resource_tag_mapping_list.*.resource_arn) == 0 ? "1" : "0"
  name = "ec2_aws_iam_role"
  role = aws_iam_role.aws_iam_role[count.index].name
}

resource "aws_instance" "aws_instance" {
  count = length(data.aws_resourcegroupstaggingapi_resources.ifExist.resource_tag_mapping_list.*.resource_arn) == 0 ? "1" : "0"
  ami           = data.aws_ami.most_recent_amazon_linux_2.id
  instance_type = "t2.micro"
  root_block_device {
    encrypted     = true
  }
  metadata_options {
    http_tokens = "optional"
  }
  iam_instance_profile = aws_iam_instance_profile.test_profile[count.index].name
  tags = local.aws_ec2_instance_tag
  depends_on = [aws_iam_instance_profile.test_profile]
}
data "aws_vpc" "default" {
  default = true
}
resource "aws_security_group" "aws-ec2-describe-security-groups" {
  name_prefix = "systest_security_group_"
  vpc_id = data.aws_vpc.default.id
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
  tags = merge(local.aws_security_group_tag, var.globaltags)
}

resource "aws_instance" "aws-create-ec2-instance-with-iam-role" {
  ami           = data.aws_ami.most_recent_amazon_linux_2.id
  instance_type = "t2.micro"
  root_block_device {
    encrypted     = true
  }
  iam_instance_profile = "ec2_aws_iam_role"
  vpc_security_group_ids = [aws_security_group.aws-ec2-describe-security-groups.id]
  tags = local.systest_ec2_instance_tag
  depends_on = [aws_iam_instance_profile.test_profile]
}
