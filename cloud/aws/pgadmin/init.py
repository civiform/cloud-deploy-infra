import json
import os
import sys

from dataclasses import dataclass


@dataclass
class DBConfig:
    address: str
    port: int
    username: str


def main():
    config = validate_env_variables()

    # See https://www.pgadmin.org/docs/pgadmin4/development/import_export_servers.html#json-format for expected format.
    data = {
        "Servers": {
            "1": {
                "Group": "CiviForm",
                "Name": "civiform-db",
                "Host": config.address,
                "Port": config.port,
                "Username": config.username,
                "SSLMode": "prefer",
                "MaintenanceDB": "postgres",
            }
        }
    }

    with open("/pgadmin4/servers.json", "w+") as f:
        json.dump(data, f)
        f.write("\n")


def validate_env_variables() -> DBConfig:
    """
    Parses expected environment variables and returns a DBConfig.

    Exits if there are any validation errors.
    """
    try:
        address = os.environ["DB_ADDRESS"]
        if address == "":
            sys.exit("DB_ADDRESS must be a non-empty string")

        port = os.environ["DB_PORT"]
        if port == "":
            sys.exit("DB_PORT must be a positive integer")
        try:
            port = int(port)
            if port < 0:
                raise ValueError
        except ValueError as e:
            sys.exit(f"DB_PORT must be a positive integer, got {port}")

        username = os.environ["DB_USERNAME"]
        if username == "":
            sys.exit("DB_USERNAME must be a non-empty string")

    except KeyError as e:
        sys.exit(f"{e.args[0]} must be present in the environment variables")

    return DBConfig(address, port, username)


if __name__ == "__main__":
    main()
