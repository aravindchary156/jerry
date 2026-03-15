resource "aws_security_group" "sonarqube" {
  name        = "hackathon-sonarqube-sg"
  description = "Security group for SonarQube"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hackathon-sonarqube-sg"
  }
}

resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.sonarqube_instance_type
  key_name                    = var.ssh_key_name
  subnet_id                   = aws_subnet.main.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]

  root_block_device {
    volume_size = var.sonarqube_root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name = "hackathon-sonarqube-vm"
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.main
  ]
}

resource "null_resource" "setup_sonarqube" {
  triggers = {
    install_script_hash = filesha256("${path.module}/install_sonarqube.sh")
    instance_id         = aws_instance.sonarqube.id
    instance_public_ip  = aws_instance.sonarqube.public_ip
  }

  depends_on = [aws_instance.sonarqube]

  provisioner "local-exec" {
    command = "for i in $(seq 1 30); do ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i \"${var.private_key_path}\" ubuntu@${aws_instance.sonarqube.public_ip} 'echo ssh-ready' >/dev/null 2>&1 && exit 0; sleep 10; done; echo 'Timed out waiting for SSH on SonarQube VM' >&2; exit 1"
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i \"${var.private_key_path}\" \"${path.module}/install_sonarqube.sh\" ubuntu@${aws_instance.sonarqube.public_ip}:/home/ubuntu/install_sonarqube.sh"
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -i \"${var.private_key_path}\" ubuntu@${aws_instance.sonarqube.public_ip} 'chmod +x /home/ubuntu/install_sonarqube.sh && sudo /home/ubuntu/install_sonarqube.sh'"
  }
}
