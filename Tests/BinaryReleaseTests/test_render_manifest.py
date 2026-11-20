import json
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RENDERER = ROOT / "scripts" / "render-binary-manifest.sh"
MODULES = (
    "NetworkingCore",
    "NetworkingRuntime",
    "NetworkingObservability",
    "NetworkingSSE",
    "Networking",
)


class BinaryReleaseManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.artifacts = Path(self.temp.name)
        for module in MODULES:
            with zipfile.ZipFile(self.artifacts / f"{module}.xcframework.zip", "w") as archive:
                archive.writestr(f"{module}.xcframework/Info.plist", "test")

    def render(self, tag="2.0.1"):
        return subprocess.run(
            ["bash", str(RENDERER), tag, str(self.artifacts), "brunogama/Networking"],
            capture_output=True,
            text=True,
        )

    def test_manifest_pins_each_published_zip_and_parses(self):
        result = self.render()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = self.artifacts / "Package.binary.swift"
        content = manifest.read_text()
        for module in MODULES:
            asset = self.artifacts / f"{module}.xcframework.zip"
            checksum = subprocess.check_output(
                ["swift", "package", "compute-checksum", str(asset)], text=True
            ).strip()
            self.assertIn(
                f"https://github.com/brunogama/Networking/releases/download/2.0.1/{asset.name}",
                content,
            )
            self.assertEqual(content.count(f'checksum: "{checksum}"'), 1)
            self.assertIn(f'name: "{module}"', content)
        self.assertNotIn("NetworkingTesting", content)
        self.assertNotIn("NetworkingObservabilityOTLP", content)
        package = self.artifacts / "Package.swift"
        shutil.copyfile(manifest, package)
        parsed = subprocess.run(
            ["swift", "package", "dump-package", "--package-path", str(self.artifacts)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(parsed.returncode, 0, parsed.stderr)
        spec = json.loads(parsed.stdout)
        self.assertEqual(len(spec["targets"]), len(MODULES))

    def test_missing_zip_fails_without_manifest(self):
        (self.artifacts / "NetworkingSSE.xcframework.zip").unlink()
        result = self.render()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.artifacts / "Package.binary.swift").exists())

    def test_invalid_tag_fails_without_manifest(self):
        result = self.render("v2.0.1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.artifacts / "Package.binary.swift").exists())


if __name__ == "__main__":
    unittest.main()
