output "ecr_image_url" {
  value = local.ecr_image_url
}

output "image_name" {
  value = var.image_name_to_pull
}

output "image_tag" {
  value = var.image_tag_to_push
}