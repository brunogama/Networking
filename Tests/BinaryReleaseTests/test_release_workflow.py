import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/release.yml"


class BinaryReleaseWorkflowTests(unittest.TestCase):
    def test_release_builds_and_uploads_each_binary_artifact_and_manifest(self):
        workflow = WORKFLOW.read_text()
        self.assertIn("scripts/build-binary-xcframeworks.sh", workflow)
        self.assertIn("Package.binary.swift", workflow)
        self.assertIn("gh release upload", workflow)
        for module in (
            "NetworkingCore",
            "NetworkingRuntime",
            "NetworkingObservability",
            "NetworkingSSE",
            "Networking",
        ):
            self.assertIn(f"{module}.xcframework.zip", workflow)

    def test_ci_and_release_workflows_run_binary_release_tests(self):
        ci_workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        release_workflow = WORKFLOW.read_text()
        command = "python3 -m unittest discover -s Tests/BinaryReleaseTests -v"
        self.assertIn(command, ci_workflow)
        self.assertIn(command, release_workflow)

    def test_annotated_tag_verification_resolves_to_a_commit(self):
        workflow = WORKFLOW.read_text()
        self.assertIn('git rev-list -n 1 "refs/tags/$TAG"', workflow)

    def test_release_stays_draft_until_assets_are_uploaded(self):
        workflow = WORKFLOW.read_text()
        release_creation = workflow.index("gh release create")
        upload = workflow.index("gh release upload")
        publish = workflow.index("gh release edit \"$TAG\" --draft=false")
        self.assertIn("--draft", workflow[release_creation:upload])
        self.assertLess(release_creation, upload)
        self.assertLess(upload, publish)
        self.assertNotIn("--clobber", workflow)
        self.assertIn("Refusing to modify published release assets", workflow)

    def test_packaging_requires_a_public_interface_for_every_archive(self):
        script = (ROOT / "scripts/build-binary-xcframeworks.sh").read_text()
        self.assertIn("! -name '*.private.swiftinterface'", script)
        self.assertIn("! -name '*.package.swiftinterface'", script)


if __name__ == "__main__":
    unittest.main()
