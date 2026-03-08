data "aws_iam_policy_document" "jenkins_ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_ec2" {
  name               = "hackathon-jenkins-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr_power_user" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "jenkins_eks_cluster_policy" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_instance_profile" "jenkins_ec2" {
  name = "hackathon-jenkins-ec2-profile"
  role = aws_iam_role.jenkins_ec2.name
}
