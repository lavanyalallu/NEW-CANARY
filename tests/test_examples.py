import json
import boto3
from botocore.config import Config
import pytest

# Load Terraform outputs
def getOutputs():
    with open("examples/outputs.json", "r") as f:
        return json.load(f)

tfOutput = getOutputs()

# Boto3 clients
cfg = Config(region_name="us-east-1")
synthetics_client = boto3.client("synthetics", config=cfg)
s3_client = boto3.client("s3", config=cfg)

def test_empty():
    assert True


def test_canary_configuration():
    """Validate Canary configuration from tfOutput."""
    canaries = tfOutput.get("synthetics_canary", {}).get("value", {})

    assert canaries, "No canaries found in tfOutput."

    for canary_name, canary_details in canaries.items():
        full_name = canary_details["name"]

        # Check name alignment
        assert full_name.endswith(canary_name), \
            f"Expected canary name to end with {canary_name}, got {full_name}"

        # Check handler
        assert canary_details["handler"] == "pageLoadBlueprint.handler"

        # ARN validations
        arn = canary_details.get("arn")
        assert arn, f"ARN missing for {canary_name}"
        assert arn.startswith("arn:aws:synthetics:")
        assert f":canary:{full_name}" in arn, \
            f"Expected ARN to contain ':canary:{full_name}', got {arn}"

        # Run config
        run_config = canary_details.get("run_config", [{}])[0]
        assert run_config.get("timeout_in_seconds") == 90

        # FIX: Add tag validation for the canary itself.
        try:
            response = synthetics_client.get_canary(Name=full_name)
            actual_tags = response.get("Canary", {}).get("Tags", {})
            
            expected_tags = tfOutput.get("module_metadata", {}).get("value", {}).get("tags", {})
            assert expected_tags, "Expected tags not found in module_metadata output."

            for k, v in expected_tags.items():
                assert actual_tags.get(k) == v, f"Canary tag '{k}' mismatch for {full_name}: expected '{v}', got '{actual_tags.get(k)}'"

        except synthetics_client.exceptions.NotFoundException:
            pytest.fail(f"The Canary '{full_name}' was not found on AWS.")


def test_s3_artifact_bucket():
    """Validate S3 artifact bucket from tfOutput exists and has tags."""
    module_metadata = tfOutput.get("module_metadata", {}).get("value", {})
    bucket_name = module_metadata.get("artifact_bucket_name")
    assert bucket_name, "S3 artifact bucket name missing in tfOutput."

    # Bucket exists?
    try:
        s3_client.head_bucket(Bucket=bucket_name)
    except s3_client.exceptions.ClientError as e:
        pytest.fail(f"S3 bucket '{bucket_name}' missing or inaccessible: {e}")

    # Check tags
    expected_tags = module_metadata.get("tags", {})
    assert expected_tags, "Expected tags missing in module_metadata."

    response = s3_client.get_bucket_tagging(Bucket=bucket_name)
    actual_tags = {tag["Key"]: tag["Value"] for tag in response.get("TagSet", [])}

    for k, v in expected_tags.items():
        assert actual_tags.get(k) == v, \
            f"Tag '{k}' mismatch: expected '{v}', got '{actual_tags.get(k)}'"


def test_synthetics_group_exists_on_aws():
    """Validate Synthetics group from tfOutput exists in AWS."""
    group = tfOutput.get("synthetics_group", {}).get("value", {})
    assert group, "Synthetics group not found in tfOutput."

    group_name = group.get("name")
    assert group_name, "Group name missing in tfOutput."

    try:
        response = synthetics_client.get_group(GroupIdentifier=group_name)
        group_details = response.get("Group")
        assert group_details, "get_group returned no group details"

        expected_tags = tfOutput.get("module_metadata", {}).get("value", {}).get("tags", {})
        actual_tags = group_details.get("Tags", {})
        for k, v in expected_tags.items():
            assert actual_tags.get(k) == v, f"Group tag '{k}' mismatch"

    except synthetics_client.exceptions.NotFoundException:
        pytest.fail(f"Synthetics group '{group_name}' not found on AWS.")


def test_canary_is_associated_with_group():
    """Check that all canaries from tfOutput are in the Synthetics group."""
    group = tfOutput.get("synthetics_group", {}).get("value", {})
    canaries = tfOutput.get("synthetics_canary", {}).get("value", {})

    if not group:
        pytest.skip("Skipping group association test; no group in tfOutput.")

    group_name = group.get("name")
    expected_canary_arns = {details["arn"] for _, details in canaries.items() if "arn" in details}

    assert expected_canary_arns, "No canary ARNs found in tfOutput."

    response = synthetics_client.list_group_resources(GroupIdentifier=group_name)
    associated_arns = set(response.get("Resources", []))

    assert expected_canary_arns.issubset(associated_arns), \
        f"Some canaries missing from group '{group_name}'"
