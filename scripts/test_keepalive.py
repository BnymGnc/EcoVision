import io
import unittest
import urllib.error
from email.message import Message
from unittest.mock import patch, MagicMock

from check_keepalive import probe, URL, EXPECTED


class KeepaliveTest(unittest.TestCase):
    def response(self, body, status=200):
        response = MagicMock()
        response.__enter__.return_value = response
        response.status = status
        response.headers = {"Content-Type": "text/plain", "Set-Cookie": "must-not-be-recorded"}
        response.read.return_value = body
        return response

    def test_valid_response_is_bounded_and_no_cookie_or_credentials_are_recorded(self):
        response = self.response(EXPECTED)
        with patch("check_keepalive.urllib.request.urlopen", return_value=response) as call:
            result = probe(URL)
        self.assertTrue(result["expectedBody"])
        self.assertEqual(200, result["status"])
        self.assertNotIn("Set-Cookie", result["headers"])
        self.assertFalse(call.call_args.args[0].has_header("Authorization"))
        response.read.assert_called_once_with(1024)
        self.assertEqual(30, call.call_args.kwargs["timeout"])

    def test_html_200_is_not_a_successful_application_probe(self):
        with patch("check_keepalive.urllib.request.urlopen", return_value=self.response(b"<html>Loading</html>")):
            self.assertFalse(probe(URL)["expectedBody"])

    def test_head_uses_empty_response(self):
        with patch("check_keepalive.urllib.request.urlopen", return_value=self.response(b"")):
            self.assertTrue(probe(URL, "HEAD")["expectedBody"])

    def test_503_is_preserved_with_limited_error_preview(self):
        headers = Message()
        headers["Server"] = "edge-example"
        headers["Retry-After"] = "60"
        headers["Set-Cookie"] = "not-recorded"
        failure = urllib.error.HTTPError(URL, 503, "Unavailable", headers, io.BytesIO(b"x" * 5000))
        with patch("check_keepalive.urllib.request.urlopen", side_effect=failure):
            result = probe(URL)
        self.assertEqual(503, result["status"])
        self.assertFalse(result["expectedBody"])
        self.assertEqual(256, len(result["responsePreview"]))
        self.assertNotIn("Set-Cookie", result["headers"])

    def test_network_timeout_is_not_hidden_or_retried(self):
        with patch("check_keepalive.urllib.request.urlopen", side_effect=TimeoutError()) as call:
            result = probe(URL)
        self.assertIsNone(result["status"])
        self.assertFalse(result["expectedBody"])
        self.assertEqual("TimeoutError", result["error"])
        call.assert_called_once()


if __name__ == "__main__":
    unittest.main()
