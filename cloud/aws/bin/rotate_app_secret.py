from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.print import print

def run(config):
  if not terraform.perform_apply(config, replace_resource='random_password.app_secret_key'):
    print('Terraform apply failed when attempting to rotate the app secret.')
    # TODO(#2606): write and upload logs.
    raise ValueError('Terraform deployment failed.')
  
  if config.is_test():
      print('Test completed')
      return

  aws = AwsCli(config)
  aws.wait_for_ecs_service_healthy()
  lb_dns = aws.get_load_balancer_dns(f'{config.app_prefix}-civiform-lb')
  base_url = config.get_base_url()
  print(
      f'Server is available at {lb_dns}. Check your domain registrar to ensure your CNAME record for {base_url} points to this address.'
  )