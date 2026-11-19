import unittest
from unittest.mock import MagicMock, patch

from cloud.shared.bin.lib import terraform


def completed(returncode):
    result = MagicMock()
    result.returncode = returncode
    return result


class TestPlanHasNoChanges(unittest.TestCase):

    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_exit_code_zero_means_no_changes(self, mock_run):
        mock_run.return_value = completed(0)

        self.assertTrue(
            terraform.plan_has_no_changes("template/dir", "terraform.tfvars"))

        command = mock_run.call_args[0][0]
        self.assertEqual(
            command[:4],
            ["terraform", "-chdir=template/dir", "plan", "-detailed-exitcode"])
        self.assertIn("-var-file=terraform.tfvars", command)
        self.assertNotIn("-destroy", command)

    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_exit_code_two_means_changes(self, mock_run):
        mock_run.return_value = completed(2)

        self.assertFalse(
            terraform.plan_has_no_changes("template/dir", "terraform.tfvars"))

    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_exit_code_one_means_error_not_empty(self, mock_run):
        mock_run.return_value = completed(1)

        self.assertFalse(
            terraform.plan_has_no_changes("template/dir", "terraform.tfvars"))

    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_passes_destroy_and_replace_to_the_plan(self, mock_run):
        mock_run.return_value = completed(2)

        terraform.plan_has_no_changes(
            "template/dir",
            "terraform.tfvars",
            is_destroy=True,
            replace_resource="aws_instance.a")

        command = mock_run.call_args[0][0]
        self.assertIn("-destroy", command)
        self.assertIn("-replace=aws_instance.a", command)


class TestPerformApply(unittest.TestCase):

    def setUp(self):
        self.config = MagicMock()
        self.config.get_template_dir.return_value = "template/dir"
        self.config.tfvars_filename = "terraform.tfvars"
        self.config.is_test.return_value = False
        self.config.skip_confirmations = False

        # Skip terraform init and pretend the tfvars file exists.
        for target in ("cloud.shared.bin.lib.terraform.perform_init",):
            patcher = patch(target)
            patcher.start()
            self.addCleanup(patcher.stop)
        exists = patch(
            "cloud.shared.bin.lib.terraform.os.path.exists", return_value=True)
        exists.start()
        self.addCleanup(exists.stop)

    @patch("cloud.shared.bin.lib.terraform.capture_stderr")
    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_empty_plan_skips_the_apply(self, mock_run, mock_capture_stderr):
        mock_run.return_value = completed(0)

        self.assertTrue(terraform.perform_apply(self.config))

        mock_capture_stderr.assert_not_called()

    @patch("cloud.shared.bin.lib.terraform.capture_stderr")
    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_plan_with_changes_runs_the_apply(
            self, mock_run, mock_capture_stderr):
        mock_run.return_value = completed(2)
        mock_capture_stderr.return_value = ("", 0)

        self.assertTrue(terraform.perform_apply(self.config))

        mock_capture_stderr.assert_called_once()
        self.assertIn(" apply ", mock_capture_stderr.call_args[0][0])

    @patch("cloud.shared.bin.lib.terraform.capture_stderr")
    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_plan_error_still_runs_the_apply(
            self, mock_run, mock_capture_stderr):
        # An error such as a state lock must reach the apply, which reports it
        # and handles it the way it always has.
        mock_run.return_value = completed(1)
        mock_capture_stderr.return_value = ("", 0)

        self.assertTrue(terraform.perform_apply(self.config))

        mock_capture_stderr.assert_called_once()

    @patch("cloud.shared.bin.lib.terraform.capture_stderr")
    @patch("cloud.shared.bin.lib.terraform.subprocess.run")
    def test_test_mode_neither_plans_nor_applies(
            self, mock_run, mock_capture_stderr):
        self.config.is_test.return_value = True

        self.assertTrue(terraform.perform_apply(self.config))

        mock_run.assert_not_called()
        mock_capture_stderr.assert_not_called()


if __name__ == "__main__":
    unittest.main()
