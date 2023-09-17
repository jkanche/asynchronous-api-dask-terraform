data "aws_ecr_image" "service_image" {
  depends_on = [null_resource.docker_build_and_push]
  for_each = { for name in var.image_names : name => name }

  repository_name = "${var.app_name}/${var.environment}/${each.value}"
  most_recent     = true
}

output "repository_urls" {
  depends_on = [null_resource.docker_build_and_push]
  description = "URLs of the ECR repositories"
  value = {
    for key, value in data.aws_ecr_image.service_image :
    key => "${local.ecr_repository_name}/${key}:${reverse(sort(value.image_tags))[0] != null ? reverse(sort(value.image_tags))[0] : "N/A"}"
  }
}


#output "repository_urls" {
#  description = "URLs of the ECR repositories"
#  value = {
#    for name in var.image_names :
#    name => "${local.ecr_repository_name}/${name}:${data.aws_ecr_image.service_image[name].image_tag != null ? data.aws_ecr_image.service_image[name].image_tag : "N/A"}"
#  }
#}

