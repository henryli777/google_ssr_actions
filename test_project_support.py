from pathlib import Path
import tempfile
import unittest

from project_support import PUBLIC_PAGES, STYLE, add_public_support, apply_to_directory, validate_source_run


class ProjectSupportTest(unittest.TestCase):
    def test_next_update_is_labeled_as_an_estimate(self):
        from public_pages import render_index
        document = render_index({'build_time_utc':'2026-10-15T00:07:00Z'})
        self.assertIn('预计下次更新时间', document)
        self.assertNotIn('>下次更新时间', document)

    def test_source_run_provenance_accepts_original_successful_build(self):
        run = {
            "id": 123,
            "status": "completed",
            "conclusion": "success",
            "head_branch": "main",
            "path": ".github/workflows/build-and-publish-subscriptions.yml",
            "repository": {"full_name": "henryli777/google_ssr_actions"},
            "head_repository": {"full_name": "henryli777/google_ssr_actions"},
        }
        validate_source_run(run, "123", "henryli777/google_ssr_actions", run["path"])

    def test_source_run_provenance_rejects_foreign_and_failed_builds(self):
        original = {
            "id": 123,
            "status": "completed",
            "conclusion": "success",
            "head_branch": "main",
            "path": ".github/workflows/build-and-publish-subscriptions.yml",
            "repository": {"full_name": "henryli777/google_ssr_actions"},
            "head_repository": {"full_name": "henryli777/google_ssr_actions"},
        }
        invalid = (
            {"id": 999},
            {"status": "in_progress"},
            {"conclusion": "failure"},
            {"head_branch": "feature"},
            {"path": ".github/workflows/foreign.yml"},
            {"repository": {"full_name": "other/google_ssr_actions"}},
            {"head_repository": {"full_name": "other/google_ssr_actions"}},
            {"head_repository": None},
        )
        for change in invalid:
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_source_run(original | change, "123", "henryli777/google_ssr_actions", original["path"])

    def test_public_html_has_persistent_header_and_footer(self):
        document = "<html><head><title>Fixture</title></head><body><main>Existing content</main></body></html>"
        result = add_public_support(document)
        self.assertIn('class="project-support-nav"', result)
        self.assertIn('class="project-support-footer"', result)
        self.assertIn("position:sticky;top:0", result)
        self.assertIn("https://support.coinexo.top/", result)
        self.assertIn('rel="noopener noreferrer"', result)
        self.assertIn("<main>Existing content</main>", result)
        self.assertEqual(add_public_support(result), result)

    def test_parser_ignores_tag_strings_and_preserves_original_source(self):
        document = "<!DOCTYPE html>\r\n<HTML><HEAD>\n<script>const tags = '<body>fake</body></head>';</script>\n</HEAD><BODY data-note='>'>Existing &amp; content</BODY></HTML>"
        result = add_public_support(document)
        self.assertIn("<script>const tags = '<body>fake</body></head>';</script>", result)
        self.assertIn("<BODY data-note='>'><!-- Henry public support navigation -->", result)
        style_removed = result.replace(STYLE, "", 1)
        navigation_start = style_removed.index("<!-- Henry public support navigation -->")
        navigation_end = style_removed.index("</nav>", navigation_start) + len("</nav>")
        original = style_removed[:navigation_start] + style_removed[navigation_end:]
        footer_start = original.index('<footer class="project-support-footer">')
        footer_end = original.index("</footer>", footer_start) + len("</footer>")
        self.assertEqual(original[:footer_start] + original[footer_end:], document)

    def test_invalid_public_document_fails_visibly(self):
        for document in ("<div>Stub</div>", "<html><head></head><body>Unclosed", "<html><body></body><head></head></html>"):
            with self.subTest(document=document), self.assertRaises(ValueError):
                add_public_support(document)

    def test_directory_preserves_public_source_line_endings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / PUBLIC_PAGES[0]).write_bytes(b"<html>\r\n<head></head>\r\n<body>Existing\r\ncontent</body></html>")
            apply_to_directory(root)
            result = (root / PUBLIC_PAGES[0]).read_bytes()
            self.assertIn(b"<html>\r\n<head>", result)
            self.assertIn(b"</head>\r\n<body>", result)
            self.assertIn(b"Existing\r\ncontent", result)

    def test_only_public_pages_change_and_error_page_is_self_contained(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = "<html><head></head><body>Snapshot content</body></html>"
            for name in (*PUBLIC_PAGES, "private.html", "login.html", "key_manager.html"):
                (root / name).write_text(original)
            (root / "health.json").write_bytes(b'{"build":"original"}')
            apply_to_directory(root)
            for name in PUBLIC_PAGES:
                self.assertIn("project-support-nav", (root / name).read_text())
            for name in ("private.html", "login.html", "key_manager.html"):
                self.assertEqual((root / name).read_text(), original)
            self.assertEqual((root / "health.json").read_bytes(), b'{"build":"original"}')
            error = (root / "404.html").read_text()
            self.assertIn("project-support-nav", error)
            self.assertNotIn('<link rel="stylesheet"', error)
            self.assertIn("https://henryli777.github.io/", error)

    def test_ui_only_upgrade_preserves_data_and_private_pages(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('<html><head></head><body>Old UI</body></html>')
            (root / 'source.html').write_text('<html><head></head><body>Old detail</body></html>')
            (root / 'private.html').write_bytes(b'private untouched')
            data = json.dumps({'build_time_utc':'2026-10-15T00:07:00Z','nodes_total':12}).encode()
            (root / 'health.json').write_bytes(data)
            apply_to_directory(root, upgrade_public_pages=True)
            index = (root / 'index.html').read_text()
            self.assertIn('public-refresh.js', index)
            self.assertIn('data-health="nodes_total">12</span>', index)
            self.assertIn('GoogleSSRRefresh.response', index)
            self.assertNotIn('runBatchSpeed(urls, 6)', index)
            self.assertTrue((root / 'public-refresh.js').is_file())
            self.assertEqual((root / 'health.json').read_bytes(), data)
            self.assertEqual((root / 'private.html').read_bytes(), b'private untouched')

    def test_rendered_public_inline_scripts_have_valid_syntax(self):
        from html.parser import HTMLParser
        import subprocess
        from public_pages import render_index

        class Scripts(HTMLParser):
            def __init__(self):
                super().__init__()
                self.inside = False
                self.parts = []
            def handle_starttag(self, tag, attrs):
                if tag == 'script':
                    self.inside = True
            def handle_endtag(self, tag):
                if tag == 'script':
                    self.inside = False
            def handle_data(self, data):
                if self.inside:
                    self.parts.append(data)

        for document in [render_index({'build_time_utc':'2026-10-15T00:07:00Z'}),
                         (Path(__file__).parent / 'static/source.html').read_text()]:
            parser = Scripts()
            parser.feed(document)
            result = subprocess.run(['node','--check'], input='\n'.join(parser.parts), text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
