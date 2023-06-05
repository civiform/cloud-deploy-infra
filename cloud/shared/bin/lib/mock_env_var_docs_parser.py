"""
This file provides helper code used for mocking out env-var-docs.parser
for testing.

The env-var-docs.parser is defined in a package in the civiform git
repository. For autogeneration of server variables the package is 
downloaded and installed dynamically.

To avoid dependencies on the env-var-docs.parser package and the dynamic 
download and installation, the content of this file is a collection of 
replacements for the actual code, which can be used for mocking out the
missing package in tests. 

For the code that the below code replaces, see:
https://github.com/civiform/civiform/blob/main/env-var-docs/parser-package/src/env_var_docs/parser.py
"""
import dataclasses
import importlib
import typing
from typing import List, Union
from unittest.mock import MagicMock


@dataclasses.dataclass
class RegexTest:
    """Replaces the Regex class in env_var_docs/parser.py """

    val: str
    should_match: bool


@dataclasses.dataclass
class Variable:
    """Replaces the Variable class in env_var_docs/parser.py """

    description: str
    type: str
    required: bool
    values: Union[List[str], None] = None
    regex: Union[str, None] = None
    regex_tests: Union[List[RegexTest], None] = None


@dataclasses.dataclass
class NodeParseError:
    """Replaces the NodeParseError class in env_var_docs/parser.py """

    path: str


@dataclasses.dataclass
class Node:
    """Replaces the Node class in env_var_docs/parser.py """

    name: str
    details: Variable


def install_mock_env_var_docs_package(self, mock_import_module):
    """ Create a mock version of the env_var_docs.parser module."""
    mock_parser = MagicMock()
    mock_parser.Variable = Variable  # Replace with your custom Variable class
    mock_parser.NodeParseError = NodeParseError
    mock_parser.Node = Node
    mock_parser.visit = MagicMock()

    def visit_mock(
            file: typing.TextIO,
            callable: typing.Callable[[Node], None]) -> List[NodeParseError]:
        node = Node(
            "test-variable-node",
            Variable("description", "string", False, [], "", []))
        callable(node)
        return []

    mock_parser.visit.side_effect = visit_mock
    mock_import_module.return_value = mock_parser


def import_mock_env_var_docs_parser(self, mock_import_module):
    """ Create a mock version of the env_var_docs.parser module and import the module"""
    mock_import_module_2 = install_mock_env_var_docs_package(
        self, mock_import_module)
    env_var_docs_parser = importlib.import_module("env_var_docs.parser")
    return env_var_docs_parser
