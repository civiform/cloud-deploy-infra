""""""   
import dataclasses
import typing

from unittest.mock import MagicMock



@dataclasses.dataclass
class RegexTest:
    """A test case for a Variable's regex.

    See parser-package/README.md for the expected JSON structure.
    """

    val: str
    """Value to test regex on."""

    should_match: bool
    """If the regex should match val."""

@dataclasses.dataclass
class Variable:
    """An environment variable referenced in application.conf.

    See parser-package/README.md for the expected JSON structure.
    """
    description: str
    type: str
    required: bool
    values: list[str] | None
    regex: str | None
    regex_tests: list[RegexTest] | None

@dataclasses.dataclass
class NodeParseError:
    """Invalid fields in the environment documentation file are reported
    through a NodeParseError. A field is invalid if it can not be successfully
    parsed as a Group or a Variable.
    """

    path: str
    """The JSON path of the invalid object."""

@dataclasses.dataclass
class Node:
    """A node within an environment variable documentation file.

    An environment variable documentation file is a JSON object that has
    object-typed fields. Valid object values are either a Group or Variable.
    """

    name: str
    """The group name or variable name. The JSON field key is the name."""

    details: Variable
    """The group details or variable details."""



# Create a mock version of the env_var_docs.parser module
def mock_out_env_var_docs_package_install(self, mock_import_module):
    mock_parser = MagicMock()
    mock_parser.Variable = Variable  # Replace with your custom Variable class
    mock_parser.NodeParseError = NodeParseError
    mock_parser.Node = Node
    mock_parser.visit = MagicMock()
    def visit_mock(file: typing.TextIO, callable: typing.Callable[[Node], None]) -> list[NodeParseError]:
        node = Node("test-variable-node", Variable("description", "string", False, [], "", []))
        callable(node)
        return []
    mock_parser.visit.side_effect = visit_mock
    mock_import_module.return_value = mock_parser

