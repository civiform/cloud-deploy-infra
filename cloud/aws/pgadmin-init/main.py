import json
import os
import sys

from dataclasses import dataclass


@dataclass
class Config:
    # Where to write the pgadmin servers import file.
    out_path: str

    # Database details to include in servers import file.
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

    with open(config.out_path, "w+") as f:
        json.dump(data, f)
        f.write("\n")


def validate_env_variables() -> Config:
    """
    Parses expected environment variables and returns a Config.

    Exits if there are any validation errors.
    """
    try:
        path = os.environ["PGADMIN_SERVER_JSON_FILE"]
        if path == "":
            sys.exit("PGADMIN_SERVER_JSON_FILE must be a non-empty string")

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

    return Config(path, address, port, username)


if __name__ == "__main__":
    main()
