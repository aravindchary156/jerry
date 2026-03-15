resource "null_resource" "setup_tools" {
  triggers = {
    install_script_hash = filesha256("${path.module}/install_tools.sh")
    dockerfile_hash     = filesha256("${path.module}/jenkins-controller.Dockerfile")
    instance_id         = aws_instance.vm.id
    instance_public_ip  = aws_instance.vm.public_ip
  }

  depends_on = [aws_instance.vm]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.vm.public_ip
    private_key = file(var.private_key_path)
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.module}/install_tools.sh"
    destination = "/home/ubuntu/install_tools.sh"
  }

  provisioner "file" {
    source      = "${path.module}/jenkins-controller.Dockerfile"
    destination = "/home/ubuntu/jenkins-controller.Dockerfile"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install_tools.sh",
      "sudo /home/ubuntu/install_tools.sh",
    ]
  }
}
