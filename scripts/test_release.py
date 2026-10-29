"""Release guards at the package, artifact, and publication boundaries."""

import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import urllib.error
import zipfile
from pathlib import Path
from unittest.mock import patch

import release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def manifests(self):
        for folder in release.MODULES:
            target = self.root / "modules" / folder
            target.mkdir(parents=True)
            shutil.copy2(release.ROOT / "modules" / folder / "moon.mod", target)

    def test_versions_require_matching_tag_modules_and_internal_dependencies(self):
        self.manifests()
        self.assertEqual(release.validate_versions(self.root, "v0.0.1"), "0.0.1")
        with self.assertRaisesRegex(ValueError, "tag"):
            release.validate_versions(self.root, "v0.0.2")
        path = self.root / "modules/cli/moon.mod"
        original = path.read_text()
        path.write_text(
            original.replace("moonsmith-engine@0.0.1", "moonsmith-engine@0.0.0")
        )
        with self.assertRaisesRegex(ValueError, "dependency version"):
            release.validate_versions(self.root)
        path.write_text(original)
        path = self.root / "modules/contracts/moon.mod"
        path.write_text(
            path.read_text().replace('version = "0.0.1"', 'version = "0.0.2"')
        )
        with self.assertRaisesRegex(ValueError, "four module versions"):
            release.validate_versions(self.root)

    def test_package_requires_license_readme_source_and_native_c_contents(self):
        module = self.root / "module"
        files = {
            "LICENSE": "license",
            "README.md": "readme",
            "moon.mod": "module",
            "src/main.mbt": "source",
            "src/moon.pkg": "package",
            "src/host/clock.c": "clock",
        }
        for name, value in files.items():
            target = module / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(value)
        archive = self.root / "package.zip"
        for missing in [
            None,
            "LICENSE",
            "README.md",
            "src/main.mbt",
            "src/host/clock.c",
        ]:
            with zipfile.ZipFile(archive, "w") as package:
                for name, value in files.items():
                    if name != missing:
                        package.writestr(name, value)
            if missing is None:
                self.assertEqual(
                    set(release.validate_package(archive, module)), set(files)
                )
            else:
                with self.assertRaisesRegex(ValueError, "missing required"):
                    release.validate_package(archive, module)
        with zipfile.ZipFile(archive, "w") as package:
            for name, value in files.items():
                package.writestr(
                    name, "wrong source" if name == "src/main.mbt" else value
                )
        with self.assertRaisesRegex(ValueError, "content mismatch"):
            release.validate_package(archive, module)

    def test_evidence_inventory_is_complete_cache_free_and_detects_tampering(self):
        source = self.root / "source"
        source.mkdir()
        (source / "main.mbt").write_text("original source")
        (source / "_build").mkdir()
        (source / "_build/cache").write_text("cache")
        (source / "linked").symlink_to(source / "main.mbt")
        archive = self.root / "evidence.tar.gz"
        release.make_archive(source, archive)
        with tarfile.open(archive) as packed:
            files = {
                member.name: packed.extractfile(member).read() for member in packed
            }
        self.assertEqual(set(files), {"main.mbt", "manifest.json", "SHA256SUMS"})
        manifest = json.loads(files["manifest.json"])
        self.assertEqual(
            manifest["files"][0]["sha256"], release.digest(b"original source")
        )
        files["main.mbt"] = b"changed source"
        with tarfile.open(archive, "w:gz") as packed:
            for name, data in files.items():
                item = tarfile.TarInfo(name)
                item.size = len(data)
                packed.addfile(item, io.BytesIO(data))
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            release.verify_archive(archive)

    def test_failed_installed_validation_keeps_partial_original_material(self):
        destination = self.root / "evidence"

        def campaign(binary, directory, **kwargs):
            directory.mkdir()
            (directory / "main.mbt").write_text("failing original source")
            (directory / "run.log").write_text("compiler failed")
            raise RuntimeError("validation failed")

        with (
            patch.object(release, "campaign", side_effect=campaign),
            self.assertRaisesRegex(RuntimeError, "validation failed"),
        ):
            release.validate_binary(Path("binary"), destination)
        self.assertEqual(
            (destination / "ordinary/main.mbt").read_text(), "failing original source"
        )
        self.assertEqual(
            (destination / "ordinary/run.log").read_text(), "compiler failed"
        )

    def test_missing_registry_version_is_distinct_from_service_failure(self):
        for status in [404, 403, 500]:
            failure = urllib.error.HTTPError(
                "https://mooncakes.io", status, "error", None, io.BytesIO()
            )
            with patch.object(release.urllib.request, "urlopen", side_effect=failure):
                if status == 404:
                    self.assertIsNone(
                        release.registry_metadata("owner/module", "1.0.0")
                    )
                else:
                    with self.assertRaises(urllib.error.HTTPError):
                        release.registry_metadata("owner/module", "1.0.0")

    def test_registry_content_check_downloads_sources_before_comparing_them(self):
        archive = self.root / "package.zip"
        with zipfile.ZipFile(archive, "w") as package:
            package.writestr("moon.mod", "expected manifest")
            package.writestr("src/main.mbt", "expected source")
        name, version = "owner/module", "0.0.1"
        for source, accepted in [
            ("expected source", True),
            ("different source", False),
        ]:

            def execute(args, *, source=source, **kwargs):
                if args[:2] == ["moon", "check"]:
                    downloaded = kwargs["cwd"] / ".mooncakes" / name
                    (downloaded / "src").mkdir(parents=True)
                    (downloaded / "moon.mod").write_text("expected manifest")
                    (downloaded / "src/main.mbt").write_text(source)
                graph = {
                    "modules": [
                        {
                            "name": name,
                            "version": version,
                            "source": {"kind": "registry"},
                        }
                    ]
                }
                return subprocess.CompletedProcess(
                    args, 0, stdout=json.dumps(graph), stderr=""
                )

            with patch.object(release, "execute", side_effect=execute):
                if accepted:
                    release.verify_registry_module(name, version, archive)
                else:
                    with self.assertRaisesRegex(
                        ValueError, "published content differs"
                    ):
                        release.verify_registry_module(name, version, archive)

    def test_publish_failure_stops_later_modules_and_cleans_credentials(self):
        packages = {}
        for folder in release.MODULES:
            archive = self.root / f"{folder}.zip"
            with zipfile.ZipFile(archive, "w") as package:
                package.writestr("moon.mod", "manifest")
            packages[folder] = archive
        published = []

        def execute(args, **kwargs):
            if args == ["moon", "publish"]:
                self.assertTrue((self.root / "credentials.json").is_file())
                self.assertEqual(
                    (self.root / "credentials.json").stat().st_mode & 0o777, 0o600
                )
                published.append(args)
                raise RuntimeError("registry unavailable")

        with (
            patch.dict(
                os.environ,
                {
                    "MOON_HOME": str(self.root),
                    "MOONCAKES_CREDENTIALS": '{"token":"test-only"}',
                },
            ),
            patch.object(release, "preflight", return_value={"version": "0.0.1"}),
            patch.object(release, "package_modules", return_value=packages),
            patch.object(release, "registry_metadata", return_value=None),
            patch.object(release, "execute", side_effect=execute),
            self.assertRaisesRegex(RuntimeError, "registry unavailable"),
        ):
            release.publish(self.root / "output", "v0.0.1")
        self.assertEqual(len(published), 1)
        self.assertFalse((self.root / "credentials.json").exists())

    def test_publication_resolves_each_dependency_before_publishing_the_next(self):
        packages = {}
        for folder, name in release.MODULES.items():
            archive = self.root / f"{folder}.zip"
            with zipfile.ZipFile(archive, "w") as package:
                package.writestr("module-name", name)
            packages[folder] = archive
        events = []
        visible = set()

        def execute(args, **kwargs):
            if args == ["moon", "publish"]:
                name = (kwargs["cwd"] / "module-name").read_text()
                events.append(("published", name))
                visible.add(name)

        def verify(name, version, archive):
            self.assertIn(name, visible)
            self.assertEqual(version, "0.0.1")
            events.append(("resolved", name))

        with (
            patch.dict(
                os.environ,
                {
                    "MOON_HOME": str(self.root),
                    "MOONCAKES_CREDENTIALS": '{"token":"test-only"}',
                },
            ),
            patch.object(release, "preflight", return_value={"version": "0.0.1"}),
            patch.object(release, "package_modules", return_value=packages),
            patch.object(
                release,
                "registry_metadata",
                side_effect=lambda name, version: {} if name in visible else None,
            ),
            patch.object(release, "verify_registry_module", side_effect=verify),
            patch.object(release, "execute", side_effect=execute),
            patch("builtins.print"),
        ):
            release.publish(self.root / "output", "v0.0.1")
        self.assertEqual(
            events,
            [
                (event, name)
                for name in release.MODULES.values()
                for event in ("published", "resolved")
            ],
        )
        self.assertFalse((self.root / "credentials.json").exists())

    def test_existing_release_mismatch_stops_before_credentials_or_publish(self):
        with (
            patch.dict(
                os.environ,
                {
                    "MOON_HOME": str(self.root),
                    "MOONCAKES_CREDENTIALS": '{"token":"test-only"}',
                },
            ),
            patch.object(release, "preflight", return_value={"version": "0.0.1"}),
            patch.object(
                release,
                "package_modules",
                return_value={
                    folder: Path("package.zip") for folder in release.MODULES
                },
            ),
            patch.object(
                release, "registry_metadata", return_value={"version": "0.0.1"}
            ),
            patch.object(
                release,
                "verify_registry_module",
                side_effect=ValueError("published content differs"),
            ),
            patch.object(release, "execute") as execute,
        ):
            with self.assertRaisesRegex(ValueError, "published content differs"):
                release.publish(self.root / "output", "v0.0.1")
            execute.assert_not_called()
        self.assertFalse((self.root / "credentials.json").exists())


if __name__ == "__main__":
    unittest.main()
