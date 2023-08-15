import sys

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform
from cloud.shared.bin.lib.print import print


def run(config):
    aws = AwsCli(config)
    previous_deployment_id = None
    info = aws.ecs_service_state()
    if info:
        previous_deployment_id = info["id"]
        if info["state"] == "IN_PROGRESS":
            answer = input(
                f"The deployment with ID {previous_deployment_id} is still in progress. Do you want to do a new deploy anyway? [y/N]> "
            )
            if answer.upper() != 'Y':
                return
            else:
                # Because previous_deployment_id is meant to detect if we've rolled back after
                # the deployment circuit breaker trips, we don't want to track the in progress
                # deployment that might still fail. But it also might succeed and be the one
                # that would get rolled back to. So fall back to wait_for_ecs_service_healthy's
                # behavior to check the deployment with the COMPLETE state against the ID
                # we found that was IN_PROGRESS when we started checking.
                previous_deployment_id = None
    if previous_deployment_id:
        print(
            f"\n*** Current deployment ID before the apply is {previous_deployment_id} ***\n"
        )

    if not terraform.perform_apply(config):
        print('Terraform deployment failed.')
        # TODO(#2606): write and upload logs.
        raise ValueError('Terraform deployment failed.')

    if config.is_test():
        print('Test completed')
        return

    aws.wait_for_ecs_service_healthy(previous_deployment_id)
    lb_dns = aws.get_load_balancer_dns(f'{config.app_prefix}-civiform-lb')
    base_url = config.get_base_url()
    print(
        f'Server is available at {lb_dns}. Check your domain registrar to ensure your CNAME record for {base_url} points to this address.'
    )
