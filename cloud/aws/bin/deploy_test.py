import os
import subprocess
import unittest

from typing import Dict, List, Optional
from unittest import mock

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
            raises: bool = False,
            configuration: Optional[Dict] = None,
            configuration_raises: bool = False,
            update_raises: bool = False):
        self._workspace = workspace
        self._upgrade_versions = upgrade_versions or []
        self._raises = raises
        self._configuration = configuration or alerting(False)
        self._configuration_raises = configuration_raises
        self._update_raises = update_raises
        self.updated_configuration: Optional[Dict] = None
        self.waited_for_active = False

    def get_grafana_workspace(self, workspace_name: str) -> Optional[Dict]:
        if self._raises:
            raise subprocess.CalledProcessError(
                1, 'aws grafana list-workspaces')
        return self._workspace

    def get_grafana_upgrade_versions(self, workspace_id: str) -> List[str]:
        return self._upgrade_versions

    def get_grafana_workspace_configuration(self, workspace_id: str) -> Dict:
        if self._configuration_raises:
            raise subprocess.CalledProcessError(
                1, 'aws grafana describe-workspace-configuration')
        return self._configuration

    def update_grafana_workspace_configuration(
            self, workspace_id: str, configuration: Dict):
        if self._update_raises:
            raise subprocess.CalledProcessError(
                1, 'aws grafana update-workspace-configuration')
        self.updated_configuration = configuration

    def wait_for_grafana_workspace_active(self, workspace_id: str):
        self.waited_for_active = True


def workspace(version: str) -> Dict:
    return {
        'id': 'g-0123456789',
        'name': 'test-civiform-metrics',
        'grafanaVersion': version
    }


def alerting(enabled: bool, plugins: bool = False) -> Dict:
    return {
        'plugins': {
            'pluginAdminEnabled': plugins
        },
        'unifiedAlerting': {
            'enabled': enabled
        }
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

    def setUp(self):
        # Skip the confirmation prompt by default. The prompt itself is
        # covered by TestGrafanaUpgradeConfirmation.
        patcher = mock.patch.dict(os.environ, {'SKIP_USER_INPUT': 'true'})
        patcher.start()
        self.addCleanup(patcher.stop)

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

    def test_exits_when_configured_version_is_not_offered(self):
        config = FakeConfig({'GRAFANA_VERSION': '11.0'})
        aws = FakeAwsCli(workspace=workspace('10.4'), upgrade_versions=['12.4'])

        with self.assertRaises(SystemExit):
            _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_exits_when_configured_version_is_not_numeric(self):
        config = FakeConfig({'GRAFANA_VERSION': '10.4-preview'})
        aws = FakeAwsCli(workspace=workspace('9.4'), upgrade_versions=['10.4'])

        with self.assertRaises(SystemExit):
            _check_for_grafana_upgrade(config, aws)

        self.assertEqual(config.added_values, {})

    def test_skips_when_workspace_version_is_not_numeric(self):
        config = FakeConfig()
        aws = FakeAwsCli(
            workspace=workspace('9.4-custom'), upgrade_versions=['10.4'])

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


class TestGrafanaAlertingBeforeV12(unittest.TestCase):

    def setUp(self):
        patcher = mock.patch.dict(os.environ, {'SKIP_USER_INPUT': 'true'})
        patcher.start()
        self.addCleanup(patcher.stop)

        self.config = FakeConfig({'GRAFANA_VERSION': '12.4'})

    def test_turns_alerting_on_before_upgrading_to_v12(self):
        aws = FakeAwsCli(
            workspace=workspace('11.0'),
            upgrade_versions=['12.4'],
            configuration=alerting(False, plugins=True))

        _check_for_grafana_upgrade(self.config, aws)

        self.assertEqual(
            aws.updated_configuration, alerting(True, plugins=True))
        self.assertTrue(aws.waited_for_active)
        self.assertEqual(self.config.added_values, {'GRAFANA_VERSION': '12.4'})

    def test_leaves_configuration_alone_when_alerting_is_already_on(self):
        aws = FakeAwsCli(
            workspace=workspace('11.0'),
            upgrade_versions=['12.4'],
            configuration=alerting(True))

        _check_for_grafana_upgrade(self.config, aws)

        self.assertIsNone(aws.updated_configuration)
        self.assertEqual(self.config.added_values, {'GRAFANA_VERSION': '12.4'})

    def test_does_not_touch_alerting_below_v12(self):
        config = FakeConfig({'GRAFANA_VERSION': '11.0'})
        aws = FakeAwsCli(
            workspace=workspace('10.4'),
            upgrade_versions=['11.0'],
            configuration_raises=True)

        _check_for_grafana_upgrade(config, aws)

        self.assertIsNone(aws.updated_configuration)
        self.assertEqual(config.added_values, {'GRAFANA_VERSION': '11.0'})

    def test_still_upgrades_when_configuration_cannot_be_read(self):
        aws = FakeAwsCli(
            workspace=workspace('11.0'),
            upgrade_versions=['12.4'],
            configuration_raises=True)

        _check_for_grafana_upgrade(self.config, aws)

        self.assertIsNone(aws.updated_configuration)
        self.assertEqual(self.config.added_values, {'GRAFANA_VERSION': '12.4'})

    def test_exits_when_alerting_cannot_be_turned_on(self):
        aws = FakeAwsCli(
            workspace=workspace('11.0'),
            upgrade_versions=['12.4'],
            update_raises=True)

        with self.assertRaises(SystemExit):
            _check_for_grafana_upgrade(self.config, aws)

        self.assertEqual(self.config.added_values, {})

    def test_does_not_change_configuration_when_user_declines(self):
        aws = FakeAwsCli(workspace=workspace('11.0'), upgrade_versions=['12.4'])

        with mock.patch.dict(os.environ, {}, clear=True):
            with mock.patch('builtins.input', return_value='n'):
                with self.assertRaises(SystemExit):
                    _check_for_grafana_upgrade(self.config, aws)

        self.assertIsNone(aws.updated_configuration)
        self.assertEqual(self.config.added_values, {})


class TestGrafanaUpgradeConfirmation(unittest.TestCase):

    def setUp(self):
        env = {k: v for k, v in os.environ.items() if k != 'SKIP_USER_INPUT'}
        patcher = mock.patch.dict(os.environ, env, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

        self.config = FakeConfig()
        self.aws = FakeAwsCli(
            workspace=workspace('9.4'),
            upgrade_versions=[MINIMUM_GRAFANA_VERSION])

    def test_applies_upgrade_when_user_confirms(self):
        with mock.patch('builtins.input', return_value='y'):
            _check_for_grafana_upgrade(self.config, self.aws)

        self.assertEqual(
            self.config.added_values,
            {'GRAFANA_VERSION': MINIMUM_GRAFANA_VERSION})

    def test_exits_without_upgrading_when_user_declines(self):
        with mock.patch('builtins.input', return_value='n'):
            with self.assertRaises(SystemExit):
                _check_for_grafana_upgrade(self.config, self.aws)

        self.assertEqual(self.config.added_values, {})

    def test_exits_without_upgrading_on_empty_answer(self):
        with mock.patch('builtins.input', return_value=''):
            with self.assertRaises(SystemExit):
                _check_for_grafana_upgrade(self.config, self.aws)

        self.assertEqual(self.config.added_values, {})

    def test_does_not_prompt_when_skip_user_input_is_set(self):
        with mock.patch.dict(os.environ, {'SKIP_USER_INPUT': 'true'}):
            with mock.patch('builtins.input') as prompt:
                _check_for_grafana_upgrade(self.config, self.aws)

        prompt.assert_not_called()
        self.assertEqual(
            self.config.added_values,
            {'GRAFANA_VERSION': MINIMUM_GRAFANA_VERSION})


if __name__ == '__main__':
    unittest.main()
