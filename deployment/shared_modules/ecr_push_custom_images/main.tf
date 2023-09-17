resource "aws_ecr_repository" "this" {
  for_each = toset(var.image_names)
  name = "${var.app_name}/${var.environment}/${each.key}"
  force_delete = true
  lifecycle { ignore_changes = [tags] }
}

locals {
  combined_services_map = zipmap(var.service_names, var.image_names)
  ecr_repository_name = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.app_name}/${var.environment}"
  timestamp = replace(timestamp(), ":", "")
}

data "external" "calculate_directory_hash" {
  for_each = { for dir in var.service_dirs : dir => dir }

  program = ["bash", "-c", "echo \"{\\\"hash\\\": \\\"$(find ${each.value} -type f -print0 | sort -z | xargs -0 shasum | shasum | cut -d ' ' -f1)\\\"}\""]
}

resource "null_resource" "docker_build_and_push" {
  for_each = local.combined_services_map

  triggers = {
    docker_compose_hash    = filesha1("${var.docker_compose_directory}/docker-compose.yml")
    combined_service_hash = join(",", [for dir in var.service_dirs : data.external.calculate_directory_hash[dir].result["hash"]])
    #dir_sha1 = sha1(join("", [for f in fileset("../${each.value}", "**"): filesha1(f)]))
  }

  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password --region ${var.aws_region} --profile ${var.aws_profile} | docker login --username AWS --password-stdin ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      docker compose -f ${var.docker_compose_directory}/docker-compose.yml build ${each.key}
      docker tag ${each.key}:latest ${local.ecr_repository_name}/${each.value}:${local.timestamp}
      docker push ${local.ecr_repository_name}/${each.value}:${local.timestamp}
    EOF
  }
}

