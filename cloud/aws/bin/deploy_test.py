import subprocess
import unittest

from typing import Dict, List, Optional

from cloud.aws.bin.deploy import MINIMUM_GRAFANA_VERSION
from cloud.aws.bin.deploy import _check_for_grafana_upgrade
from cloud.aws.bin.deploy import _parse_version


class FakeConfig:

    def __init__(self, config_vars: Optional[Dict[str, str]] = None):
        self.app_prefix = 'test'
        self._config_vars = config_vars or {}
        self.added_values: Dict[str, str] = {}

    def get_config_var(self, key: str) -> Optional[str]:
        return self._config_vars.get(key)

    def add_config_value(self, key: str, value: str):
        self.added_values[key] = value


class FakeAwsCli:

    def __init__(
            self,
            workspace: Optional[Dict] = None,
            upgrade_versions: Optional[List[str]] = None,
            raises: bool = False):
        self._workspace = workspace
        self._upgrade_versions = upgrade_versions or []
        self._raises = raises

    def get_grafana_workspace(self, workspace_name: str) -> Optional[Dict]:
        if self._raises:
            raise subprocess.CalledProcessError(
                1, 'aws grafana list-workspaces')
        return self._workspace

    def get_grafana_upgrade_versions(self, workspace_id: str) -> List[str]:
        return self._upgrade_versions


def workspace(version: str) -> Dict:
    return {
        'id': 'g-0123456789',
        'name': 'test-civiform-metrics',
        'grafanaVersion': version
    }


class TestParseVersion(unittest.TestCase):

    def test_parses_into_comparable_tuple(self):
        self.assertEqual(_parse_version('10.4'), (10, 4))

    def test_orders_by_number_and_not_by_string(self):
        self.assertLess(_parse_version('9.4'), _parse_version('10.4'))
        self.assertLess(_parse_version('10.4'), _parse_version('12.4'))

    def test_raises_on_unparseable_version(self):
        with self.assertRaises(ValueError):
            _parse_version('10.4-preview')


class TestCheckForGrafanaUpgrade(unittest.TestCase):

    def test_upgrades_workspace_below_the_floor(self):
        config = FakeConfig()
        aws = FakeAwsCli(
            workspace=workspace('9.4'),
            upgrade_versions=[MINIMUM_GRAFANA_VERSION])

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(
            config.added_values, {'GRAFANA_VERSION': MINIMUM_GRAFANA_VERSION})

    def test_leaves_workspace_already_at_the_floor_alone(self):
        config = FakeConfig()
        aws = FakeAwsCli(workspace=workspace(MINIMUM_GRAFANA_VERSION))

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_does_not_downgrade_workspace_above_the_floor(self):
        config = FakeConfig()
        aws = FakeAwsCli(workspace=workspace('12.4'))

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_exits_when_configured_version_is_older_than_the_workspace(self):
        config = FakeConfig({'GRAFANA_VERSION': '10.4'})
        aws = FakeAwsCli(workspace=workspace('12.4'))

        with self.assertRaises(SystemExit):
            _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_uses_configured_version_when_it_is_an_upgrade(self):
        config = FakeConfig({'GRAFANA_VERSION': '12.4'})
        aws = FakeAwsCli(workspace=workspace('10.4'), upgrade_versions=['12.4'])

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {'GRAFANA_VERSION': '12.4'})

    def test_steps_towards_the_target_when_it_is_not_offered_yet(self):
        config = FakeConfig()
        aws = FakeAwsCli(workspace=workspace('8.4'), upgrade_versions=['9.4'])

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {'GRAFANA_VERSION': '9.4'})

    def test_takes_the_largest_step_that_does_not_pass_the_target(self):
        config = FakeConfig({'GRAFANA_VERSION': '10.4'})
        aws = FakeAwsCli(
            workspace=workspace('8.4'),
            upgrade_versions=['9.4', '10.4', '12.4'])

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {'GRAFANA_VERSION': '10.4'})

    def test_skips_when_aws_offers_nothing_towards_the_target(self):
        config = FakeConfig()
        aws = FakeAwsCli(workspace=workspace('9.4'), upgrade_versions=[])

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_ignores_unparseable_offered_versions(self):
        config = FakeConfig()
        aws = FakeAwsCli(
            workspace=workspace('9.4'),
            upgrade_versions=['10.4-preview', '10.4'])

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {'GRAFANA_VERSION': '10.4'})

    def test_skips_when_there_is_no_workspace(self):
        config = FakeConfig()
        aws = FakeAwsCli(workspace=None)

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_skips_when_the_workspace_lookup_fails(self):
        config = FakeConfig()
        aws = FakeAwsCli(raises=True)

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_skips_when_the_workspace_version_is_unparseable(self):
        config = FakeConfig()
        aws = FakeAwsCli(workspace=workspace('unknown'))

        _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})


if __name__ == '__main__':
    unittest.main()
