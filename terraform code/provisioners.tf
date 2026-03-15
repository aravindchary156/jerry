resource "null_resource" "setup_tools" {
  triggers = {
    install_script_hash = filesha256("${path.module}/install_tools.sh")
    dockerfile_hash     = filesha256("${path.module}/jenkins-controller.Dockerfile")
    instance_id         = aws_instance.vm.id
    instance_public_ip  = aws_instance.vm.public_ip
  }

  depends_on = [aws_instance.vm]

  provisioner "local-exec" {
    command = "for i in $(seq 1 30); do ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i \"${var.private_key_path}\" ubuntu@${aws_instance.vm.public_ip} 'echo ssh-ready' >/dev/null 2>&1 && exit 0; sleep 10; done; echo 'Timed out waiting for SSH on Jenkins VM' >&2; exit 1"
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i \"${var.private_key_path}\" \"${path.module}/install_tools.sh\" ubuntu@${aws_instance.vm.public_ip}:/home/ubuntu/install_tools.sh"
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i \"${var.private_key_path}\" \"${path.module}/jenkins-controller.Dockerfile\" ubuntu@${aws_instance.vm.public_ip}:/home/ubuntu/jenkins-controller.Dockerfile"
  }

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -i \"${var.private_key_path}\" ubuntu@${aws_instance.vm.public_ip} 'chmod +x /home/ubuntu/install_tools.sh && sudo /home/ubuntu/install_tools.sh'"
  }
}
