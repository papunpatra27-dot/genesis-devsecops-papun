output "k3s_node_role_name"       { value = aws_iam_role.k3s_node.name }
output "k3s_node_role_arn"        { value = aws_iam_role.k3s_node.arn }
output "github_actions_role_arn"  { value = aws_iam_role.github_actions.arn }
output "oidc_provider_arn"        { value = aws_iam_openid_connect_provider.github_actions.arn }
