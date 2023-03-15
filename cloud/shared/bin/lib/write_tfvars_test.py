import unittest
import os

from cloud.shared.bin.lib.write_tfvars import TfVarWriter
"""
 Tests for the WriteTfVars, calls the I/O methods to match the actual 
 experience of running the class. 
 
 To run the tests: python3 cloud/shared/bin/lib/write_tfvars_test.py
"""


class TestWriteTfVars(unittest.TestCase):

    def setUp(self):
        self.fake_tfvars_filename = "fake_vars.tfvars"
        with open(self.fake_tfvars_filename, "w") as tf_vars:
            tf_vars.write("")

    def teardown(self):
        os.remove(self.fake_tfvars_filename)

    def test_writes_file_with_correct_formatting(self):
        config_loader = TfVarWriter(self.fake_tfvars_filename)
        config_loader.write_variables({"test": "success", "env": "test"})
        with open(self.fake_tfvars_filename, "r") as tf_vars:
            self.assertEqual(tf_vars.read(), 'test="success"\nenv="test"\n')

    def test_writes_file_with_none(self):
        config_loader = TfVarWriter(self.fake_tfvars_filename)
        config_loader.write_variables({"test": None})
        with open(self.fake_tfvars_filename, "r") as tf_vars:
            self.assertEqual(tf_vars.read(), '')

    def test_writes_files_with_civiform_server_environment_variables(self):
        config_loader = TfVarWriter(self.fake_tfvars_filename)
        config_loader.write_variables(
            {
                "test": "true",
                "civiform_server_environment_variables":
                    {
                        "MY_VAR": "Is cool",
                        "FEATURE_ENABLED": "false"
                    }
            })
        with open(self.fake_tfvars_filename, "r") as tf_vars:
            self.assertEqual(
                tf_vars.read(),
                'test="true"\nciviform_server_environment_variables = {\n  "MY_VAR"="Is cool"\n  "FEATURE_ENABLED"="false"\n}\n'
            )


if __name__ == "__main__":
    unittest.main()
