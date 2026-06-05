output "instance_id"       { value = aws_instance.k3s.id }
output "public_ip"         { value = aws_eip.k3s.public_ip }
output "private_ip"        { value = aws_instance.k3s.private_ip }
output "instance_profile"  { value = aws_iam_instance_profile.k3s.name }
