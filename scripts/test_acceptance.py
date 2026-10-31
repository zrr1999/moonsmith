"""CI acceptance checks preserve package contents and replay evidence."""

import hashlib
import io
import json
import shutil
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import acceptance


class AcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def manifests(self):
        for folder in acceptance.MODULES:
            target = self.root / "modules" / folder
            target.mkdir(parents=True)
            shutil.copy2(acceptance.ROOT / "modules" / folder / "moon.mod", target)

    def test_versions_require_matching_modules_and_internal_dependencies(self):
        self.manifests()
        self.assertEqual(acceptance.validate_versions(self.root), "0.0.1")
        path = self.root / "modules/cli/moon.mod"
        original = path.read_text()
        path.write_text(
            original.replace("moonsmith-engine@0.0.1", "moonsmith-engine@0.0.0")
        )
        with self.assertRaisesRegex(ValueError, "dependency version"):
            acceptance.validate_versions(self.root)
        path.write_text(original)
        path = self.root / "modules/contracts/moon.mod"
        path.write_text(
            path.read_text().replace('version = "0.0.1"', 'version = "0.0.2"')
        )
        with self.assertRaisesRegex(ValueError, "four module versions"):
            acceptance.validate_versions(self.root)

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
                    set(acceptance.validate_package(archive, module)), set(files)
                )
            else:
                with self.assertRaisesRegex(ValueError, "missing required"):
                    acceptance.validate_package(archive, module)
        with zipfile.ZipFile(archive, "w") as package:
            for name, value in files.items():
                package.writestr(
                    name, "wrong source" if name == "src/main.mbt" else value
                )
        with self.assertRaisesRegex(ValueError, "content mismatch"):
            acceptance.validate_package(archive, module)

    def test_evidence_inventory_is_complete_cache_free_and_detects_tampering(self):
        source = self.root / "source"
        source.mkdir()
        (source / "main.mbt").write_text("original source")
        (source / "_build").mkdir()
        (source / "_build/cache").write_text("cache")
        (source / "linked").symlink_to(source / "main.mbt")
        archive = self.root / "evidence.tar.gz"
        acceptance.make_archive(source, archive)
        with tarfile.open(archive) as packed:
            files = {
                member.name: packed.extractfile(member).read() for member in packed
            }
        self.assertEqual(set(files), {"main.mbt", "manifest.json", "SHA256SUMS"})
        manifest = json.loads(files["manifest.json"])
        self.assertEqual(
            manifest["files"][0]["sha256"], acceptance.digest(b"original source")
        )
        files["main.mbt"] = b"changed source"
        with tarfile.open(archive, "w:gz") as packed:
            for name, data in files.items():
                item = tarfile.TarInfo(name)
                item.size = len(data)
                packed.addfile(item, io.BytesIO(data))
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            acceptance.verify_archive(archive)

    def checked_archive(self):
        source = self.root / "content"
        source.mkdir()
        (source / "payload.txt").write_text("release evidence")
        archive = self.root / "checked.tar.gz"
        acceptance.make_archive(source, archive)
        return archive

    def corrupt_archive(self, archive):
        with tarfile.open(archive) as packed:
            files = {
                member.name: packed.extractfile(member).read() for member in packed
            }
        files["payload.txt"] = b"changed evidence"
        with tarfile.open(archive, "w:gz") as packed:
            for name, data in files.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                packed.addfile(member, io.BytesIO(data))

    def test_historical_evidence_requires_reviewed_digest_and_valid_contents(self):
        archive = self.checked_archive()
        manifest = self.root / "release-evidence.json"
        expected = {
            "file": archive.name,
            "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        }
        manifest.write_text(json.dumps(expected))
        acceptance.verify_historical_evidence(self.root, manifest)

        self.corrupt_archive(archive)
        with self.assertRaisesRegex(ValueError, "reviewed manifest"):
            acceptance.verify_historical_evidence(self.root, manifest)
        expected["sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
        manifest.write_text(json.dumps(expected))
        with self.assertRaisesRegex(ValueError, "archive checksum mismatch"):
            acceptance.verify_historical_evidence(self.root, manifest)

    def test_failed_installed_validation_keeps_partial_original_material(self):
        destination = self.root / "evidence"

        def campaign(binary, directory, **kwargs):
            directory.mkdir()
            (directory / "main.mbt").write_text("failing original source")
            (directory / "run.log").write_text("compiler failed")
            raise RuntimeError("validation failed")

        with (
            patch.object(acceptance, "campaign", side_effect=campaign),
            self.assertRaisesRegex(RuntimeError, "validation failed"),
        ):
            acceptance.validate_binary(Path("binary"), destination)
        self.assertEqual(
            (destination / "ordinary/main.mbt").read_text(), "failing original source"
        )
        self.assertEqual(
            (destination / "ordinary/run.log").read_text(), "compiler failed"
        )


if __name__ == "__main__":
    unittest.main()
