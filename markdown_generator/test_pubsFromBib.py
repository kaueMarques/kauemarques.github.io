import unittest
import sys
import os
from unittest.mock import patch, MagicMock, mock_open

import importlib

class TestPubsFromBib(unittest.TestCase):
    @patch('builtins.open', new_callable=mock_open)
    @patch('pybtex.database.input.bibtex.Parser.parse_file')
    def test_empty_bib(self, mock_parse_file, mock_file_open):
        """Test that providing an empty bibtex file results in no output files generated."""

        # Setup mock to return empty entries dictionary simulating empty bib file
        mock_bibdata = MagicMock()
        mock_bibdata.entries = {}
        mock_parse_file.return_value = mock_bibdata

        # Add the directory to sys.path so we can import it
        sys.path.insert(0, os.path.abspath('markdown_generator'))

        # Import or reload if already imported
        if 'pubsFromBib' in sys.modules:
            importlib.reload(sys.modules['pubsFromBib'])
        else:
            import pubsFromBib

        # Verify parse_file was called (for the items in publist)
        self.assertTrue(mock_parse_file.called)

        # Verify open was not called for writing files since entries are empty
        write_calls = [call for call in mock_file_open.mock_calls if 'w' in call.args or call.kwargs.get('mode') == 'w']
        self.assertEqual(len(write_calls), 0)

if __name__ == '__main__':
    unittest.main()
