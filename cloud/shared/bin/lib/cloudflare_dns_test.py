import os
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from cloud.shared.bin.lib import cloudflare_dns
from cloud.shared.bin.lib.config_loader import ConfigLoader


class TestCloudflareDns(unittest.TestCase):

    def setUp(self):
        self.config = ConfigLoader()
        self.config._config_fields = {
            "APP_PREFIX": "test-app",
            "AWS_REGION": "us-east-1",
            "ENABLE_CLOUDFLARE_DNS": "true",
            "CLOUDFLARE_RECORD_NAME": "my-instance",
            "CLOUDFLARE_ZONE_ID": "mock-zone-id",
            "CLOUDFLARE_API_TOKEN": "mock-token",
            "CLOUDFLARE_TTL": "300",
            "CLOUDFLARE_PROXIED": "false",
        }

    def test_is_dns_enabled(self):
        self.assertTrue(cloudflare_dns.is_dns_enabled(self.config))

        self.config._config_fields["ENABLE_CLOUDFLARE_DNS"] = "false"
        self.assertFalse(cloudflare_dns.is_dns_enabled(self.config))

        del self.config._config_fields["ENABLE_CLOUDFLARE_DNS"]
        self.assertFalse(cloudflare_dns.is_dns_enabled(self.config))

    def test_write_tfvars(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch("cloud.shared.bin.lib.cloudflare_dns.get_module_dir", return_value=tmpdir):
                cloudflare_dns.write_tfvars(self.config, "my-load-balancer.elb.amazonaws.com")

                tfvars_file = os.path.join(tmpdir, "setup.auto.tfvars")
                self.assertTrue(os.path.exists(tfvars_file))

                with open(tfvars_file, "r") as f:
                    content = f.read()

                self.assertIn('cloudflare_api_token = "mock-token"', content)
                self.assertIn('cloudflare_zone_id   = "mock-zone-id"', content)
                self.assertIn('record_name          = "my-instance"', content)
                self.assertIn('target_dns_name      = "my-load-balancer.elb.amazonaws.com"', content)
                self.assertIn('app_prefix           = "test-app"', content)
                self.assertIn('ttl                  = 300', content)
                self.assertIn('proxied              = false', content)

    def test_setup_backend_remote(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch("cloud.shared.bin.lib.cloudflare_dns.get_module_dir", return_value=tmpdir):
                cloudflare_dns.setup_backend(self.config)

                backend_file = os.path.join(tmpdir, "backend_vars")
                self.assertTrue(os.path.exists(backend_file))

                with open(backend_file, "r") as f:
                    content = f.read()

                self.assertIn('bucket         = "test-app-civiform-backendstate"', content)
                self.assertIn('key            = "tfstate/cloudflare-dns.tfstate"', content)
                self.assertIn('region         = "us-east-1"', content)
                self.assertIn('dynamodb_table = "test-app-civiform-locktable"', content)

    def test_setup_backend_local(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a mock backend_override file
            with open(os.path.join(tmpdir, "backend_override"), "w") as f:
                f.write('terraform { backend "local" {} }')

            self.config._config_fields["USE_LOCAL_BACKEND"] = True
            with patch("cloud.shared.bin.lib.cloudflare_dns.get_module_dir", return_value=tmpdir):
                cloudflare_dns.setup_backend(self.config)

                override_file = os.path.join(tmpdir, "backend_override.tf")
                self.assertTrue(os.path.exists(override_file))

    @patch("cloud.shared.bin.lib.terraform.perform_apply", return_value=True)
    def test_apply_dns(self, mock_perform_apply):
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch("cloud.shared.bin.lib.cloudflare_dns.get_module_dir", return_value=tmpdir):
                result = cloudflare_dns.apply_dns(self.config, "my-lb.elb.amazonaws.com")
                self.assertTrue(result)
                mock_perform_apply.assert_called_once_with(
                    self.config,
                    is_destroy=False,
                    terraform_template_dir=tmpdir,
                )

    @patch("cloud.shared.bin.lib.terraform.perform_apply", return_value=True)
    def test_apply_dns_when_disabled(self, mock_perform_apply):
        self.config._config_fields["ENABLE_CLOUDFLARE_DNS"] = "false"
        result = cloudflare_dns.apply_dns(self.config, "my-lb.elb.amazonaws.com")
        self.assertTrue(result)
        mock_perform_apply.assert_not_called()

    @patch("cloud.shared.bin.lib.terraform.perform_apply", return_value=True)
    def test_destroy_dns(self, mock_perform_apply):
        with tempfile.TemporaryDirectory() as tmpdir:
            with patch("cloud.shared.bin.lib.cloudflare_dns.get_module_dir", return_value=tmpdir):
                result = cloudflare_dns.destroy_dns(self.config)
                self.assertTrue(result)
                mock_perform_apply.assert_called_once_with(
                    self.config,
                    is_destroy=True,
                    terraform_template_dir=tmpdir,
                )

    @patch("cloud.shared.bin.lib.terraform.perform_apply", return_value=True)
    def test_destroy_dns_when_disabled(self, mock_perform_apply):
        self.config._config_fields["ENABLE_CLOUDFLARE_DNS"] = "false"
        result = cloudflare_dns.destroy_dns(self.config)
        self.assertTrue(result)
        mock_perform_apply.assert_not_called()


if __name__ == "__main__":
    unittest.main()
