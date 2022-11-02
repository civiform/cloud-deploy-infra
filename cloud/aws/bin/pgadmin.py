import os
import sys
import time
import re
import urllib.error
import urllib.request

from cloud.aws.templates.aws_oidc.bin import resources
from cloud.aws.templates.aws_oidc.bin.aws_cli import AwsCli
from cloud.shared.bin.lib import terraform


def run(config):
    os.environ["TF_VAR_pgadmin_cidr_allowlist"] = get_cidr_list()
    os.environ["TF_VAR_pgadmin"] = "true"

    if not terraform.perform_apply(config):
        sys.stderr.write("Terraform deployment failed.")
        raise ValueError("Terraform deployment failed.")

    pgurl = f"{config.get_base_url()}:4433"
    print(
        "\npgadmin terraform deployment finished. Waiting for pgadmin service (some request failures are expected):"
    )
    wait_for_pgadmin_response(pgurl)

    print(f"\npgadmin service is available. URL: {pgurl}")
    print_secrets(config)

    input(
        "\nWARNING: it is strongly recommended to clean up pgadmin resources once they are no-longer needed.\n"
        "Run 'bin/deploy --tag=latest' to manually clean up pgadmin resources.\n\n"
        "Waiting to clean up pgadmin resources.  Press enter to trigger cleanup...\n"
    )

    os.unsetenv("TF_VAR_pgadmin_cidr_allowlist")
    os.unsetenv("TF_VAR_pgadmin")
    if not terraform.perform_apply(config):
        sys.stderr.write("Terraform deployment failed.")
        raise ValueError("Terraform deployment failed.")


def get_cidr_list() -> str:
    print()

    while True:
        got = input(
            "\nREQUIRED: input a comma-separated list of IPv4 CIDR blocks that should have access to the pgadmin service:\n"
            "To allow a single IP address, use a subnet mask of 32. For example: '192.0.0.1/32'\n"
            "> ")

        # Validate each block in list.
        #
        # Regexp is from cloud/aws/modules/pgadmin/variables.tf.
        matcher = re.compile(
            "^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))$")
        errors = False
        blocks = [x.strip() for x in got.split(",")]
        for b in blocks:
            if matcher.fullmatch(b) == None:
                print(f"  ERROR: '{b}' is not a valid CIDR block.")
                errors = True
        if errors:
            print("Invalid CIDR blocks found.  Please re-enter list.")
            continue

        # Terraform expects lists in the `["item1", "item2", ..., "itemN"]` format:
        # https://developer.hashicorp.com/terraform/language/values/variables#variables-on-the-command-line
        #
        # Notably, single quotes are not valid. Strings in lists formatted in f-strings are wrapped in single
        # quotes so we need to replace them with double quotes.
        formatted = f"{blocks}".replace("'", '"')
        print(f"Parsed list: {formatted}")
        y = input(
            "\nAccept CIDR list? (anything entered other than 'y' will cause list to be re-entered): "
        )
        if y == "y":
            print()
            break

    return formatted


def wait_for_pgadmin_response(url):
    while True:
        error = ""
        try:
            r = urllib.request.urlopen(f"{url}/misc/ping")
            if r.getcode() != 200:
                error = f"expected HTTP code 200, got {r.getcode()}"
            else:
                break
        except urllib.error.URLError as e:
            error = f"{e}"

        print(f"  {error}. Retrying in 10 seconds...")
        time.sleep(10)


def print_secrets(config):
    aws = AwsCli(config)
    prefix = f"{config.app_prefix}-civiform"
    print(
        f"  pgadmin default email: {aws.get_secret_value(prefix + '-pgadmin-default-username')}\n"
        f"  pgadmin default password: {aws.get_secret_value(prefix + '-pgadmin-default-password')}\n"
        f"  postgres database password: {aws.get_secret_value(prefix + '_postgres_password')}"
    )
