output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "reverse_proxy_public_ip" {
  value = aws_instance.reverse_proxy.public_ip
}

